#!/bin/sh
set -e

# Remember original directory (where script and dropbearmulti are)
BASE_DIR="$(dirname "$0")"
BASE_DIR="$(cd "$BASE_DIR" && pwd)"

# Load kernel modules
modprobe libcomposite
modprobe usb_f_rndis

# Setup USB gadget in gadget configfs dir
GADGET_DIR=/sys/kernel/config/usb_gadget/g1
mkdir -p "$GADGET_DIR"
cd "$GADGET_DIR"

echo 0x1d6b > idVendor
echo 0x0104 > idProduct

mkdir -p strings/0x409
echo "12345678" > strings/0x409/serialnumber
echo "Linux" > strings/0x409/manufacturer
echo "R36 emulation console" > strings/0x409/product

mkdir -p configs/c.1
echo 100 > configs/c.1/MaxPower

mkdir -p functions/rndis.usb0
ln -sf functions/rndis.usb0 configs/c.1/

echo ff300000.usb > UDC

ifconfig usb0 192.168.7.2 netmask 255.255.255.0 up

# Back to original directory to run dropbearmulti
cd "$BASE_DIR"

if [ ! -x ./dropbearmulti ]; then
  echo "Error: dropbearmulti binary not found or not executable in $BASE_DIR"
  exit 1
fi

KEYS="dropbear_rsa_host_key dropbear_dss_host_key dropbear_ecdsa_host_key dropbear_ed25519_host_key"
for key in $KEYS; do
  if [ ! -f "$key" ]; then
    echo "Generating $key ..."
    case "$key" in
      dropbear_rsa_host_key) TYPE=rsa ;;
      dropbear_dss_host_key) TYPE=dss ;;
      dropbear_ecdsa_host_key) TYPE=ecdsa ;;
      dropbear_ed25519_host_key) TYPE=ed25519 ;;
    esac
    ./dropbearmulti dropbearkey -t "$TYPE" -f "$key"
  else
    echo "$key already exists, skipping generation."
  fi
done

# --- Best effort: expose an 'scp' binary so file transfers work ---------------
# dropbearmulti may include the scp applet; without an 'scp' in the remote PATH,
# "scp -O" from the client fails with "scp: command not found".
if ./dropbearmulti 2>&1 | grep -qi scp; then
  for d in /usr/local/bin /usr/bin /bin; do
    if [ -d "$d" ] && [ -w "$d" ]; then
      ln -sf "$BASE_DIR/dropbearmulti" "$d/scp" 2>/dev/null && break
    fi
  done
fi

# --- Show connection info on the display instead of a black screen ------------
# EmuELEC ships ffplay, so we display a static PNG with the connection details.
# Fallback: plain text to /dev/console.
INFO_PID=""
INFO_PNG="$BASE_DIR/icons/ssh_info.png"
if command -v ffplay >/dev/null 2>&1 && [ -f "$INFO_PNG" ]; then
  ffplay -fs -loop 0 -loglevel quiet "$INFO_PNG" >/dev/null 2>&1 &
  INFO_PID=$!
else
  clear > /dev/console 2>/dev/null || true
  {
    echo ""
    echo "  === SSH over USB - SERVER RUNNING ==="
    echo ""
    echo "  Console IP : 192.168.7.2"
    echo "  PC IP      : 192.168.7.1 (set it manually, /24)"
    echo "  Login      : root / emuelec"
    echo ""
    echo "  ssh root@192.168.7.2"
    echo ""
    echo "  EXIT: press RESET (or run 'reboot' via ssh)"
  } > /dev/console 2>/dev/null || true
fi

# Kill the info screen when the server stops
trap '[ -n "$INFO_PID" ] && kill "$INFO_PID" 2>/dev/null' EXIT INT TERM

echo "Starting Dropbear SSH server..."
./dropbearmulti dropbear -p 22 \
  -r dropbear_rsa_host_key \
  -r dropbear_dss_host_key \
  -r dropbear_ecdsa_host_key \
  -r dropbear_ed25519_host_key \
  -F -E
