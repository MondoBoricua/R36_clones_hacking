#!/bin/sh
# Launcher for the "Ports" system in EmulationStation.
# Auto-detects the roms root (it varies between firmwares) and runs the port.
for base in /storage/roms /roms /roms2 /storage/roms2 /userdata/roms; do
  if [ -f "$base/ports_scripts/ssh_over_usb/ssh_over_usb.sh" ]; then
    exec sh "$base/ports_scripts/ssh_over_usb/ssh_over_usb.sh"
  fi
done
echo "ERROR: ports_scripts/ssh_over_usb/ssh_over_usb.sh not found on the SD card"
sleep 5
exit 1
