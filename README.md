# R36 clone SSH connection via USB
A guide on how to make your R36 clone connect via ssh through USB

You bought an R36 clone and you don't know what to do with it ? Don't worry, I was in the same situation than you a few days ago. 
Because I like to tinker, and thanks to the post of u/Careful-Ad3182 and u/Ill-Improvement-2003 on reddit, I was able to connect to my console via UART, and by that I mean that I have access to the internal 8gb storage chip of my R36S (pro in my case). Using UART gives a direct shell root access, so it was not real hacking, but I felt very proud. I was somewhere I shouldn't be, and I had the control to modify what I wanted inside the console ! What a boost of adrenaline ! 

WARNING : this is not a tutorial for beginners. it is a proof of concept that having a ssh connection to your machine via OTG is possible.


# Prerequisites
- An R36S (pro, but R36S should be the same, probably works for K36s and R36 MAX too with some adjustments ? )
- USB-OTG compatibe cables
- A computer running Windows/Linux

# Setup the SD card : 
Download the latest release (for now EZ-installer.zip) and unzip it to the root of your SD card. There should be no overwrites. Put the sd back in the console

# Launch the script
We use the fact that the "Ports" system in ` /storage/.emulationstation/es_systems.cfg ` uses the shell terminal to execute the scripts.
Open the "Ports" system. if there's nothing accessible there, go to the EmuElec settings and check the "see empty systems". That would be strange but not impossible. If you still see not script, there's a problem. If you do see the program, run it. You should be greeted with an info screen showing the connection details (on systems without `ffplay` you may get a black screen instead — the server is running anyway). Now you can connect the device to your computer with an USB cable, and you should hear the sound that a device has been connected. Note that it is registered as a "Network adapter" and not a usb device ("Remote NDIS based Internet Sharing Device" on Windows).

The **console** is `192.168.7.2`, so your **PC** must be `192.168.7.1` (replace "Ethernet 2" with the name of the RNDIS adapter, see `Get-NetAdapter` in PowerShell):

```cmd
netsh interface ip set address "Ethernet 2" static 192.168.7.1 255.255.255.0
```

and then try to ping it
(The script takes ~5-10s to load, so be a little patient before trying to ping the device.)

```cmd
ping 192.168.7.2
```
if your ping was successful, you can now try to run the command
```cmd
ssh root@192.168.7.2
```

It will ask for a password. Mine was "emuelec" but if it doesn't work, you could just try a blank password. 

To exit the ssh server, the simplest options are pressing the reset button, or running `reboot` from inside the ssh session (clean reboot, tested on EmuELEC 4.7).

# Transferring files

Modern OpenSSH clients default to the SFTP protocol, which Dropbear does not serve, so a plain `scp file root@192.168.7.2:/path` fails. Options:

- `scp -O file root@192.168.7.2:/path` (legacy scp protocol) — works if an `scp` binary is available on the console (the launch script now tries to symlink one from `dropbearmulti` automatically).
- Fallback that always works (Windows):
  ```cmd
  type file.bin | ssh root@192.168.7.2 "cat > /storage/roms/file.bin"
  ```
  (verify with `md5sum` on the console vs `certutil -hashfile file.bin MD5` on Windows)

There also is a "terminal" that lauches the on-screen terminal of the device (requires a keyboard attached to OTG port)

# Issues you could have :
- readonly file system
  -> solution : find your partition ( with df -h ) and do
  `mount -o remount,rw /dev/mmcblk0p3`
  where mmcblk0p3 is the partition's name

  example of df -h :
  ```shell
  RuiSuo:~ # df -h
  Filesystem                Size      Used Available Use% Mounted on
  devtmpfs                416.9M      4.0K    416.9M   0% /dev
  tmpfs                   193.8M      2.1M    191.7M   1% /run
  /dev/mmcblk0p3         1023.7M   1009.4M     14.4M  99% /flash
  /dev/loop0              978.5M    978.5M         0 100% /
  /dev/mmcblk0p5            4.5G    484.2M      4.0G  11% /storage 
  tmpfs                   484.5M         0    484.5M   0% /dev/shm
  tmpfs                     4.0M         0      4.0M   0% /sys/fs/cgroup
  tmpfs                   484.5M     32.0K    484.5M   0% /var
  tmpfs                   484.5M         0    484.5M   0% /tmp
  /dev/mmcblk2p1           87.9G     48.3G     39.5G  55% /storage/roms
  /dev/mmcblk2p1           87.9G     48.3G     39.5G  55% /storage/.update
  none                      4.5G    484.2M      4.0G  11% /tmp/assets
  none                      4.5G    484.2M      4.0G  11% /tmp/cores
  none                      4.5G    484.2M      4.0G  11% /tmp/database
  none                      4.5G    484.2M      4.0G  11% /tmp/joypads
  none                      4.5G    484.2M      4.0G  11% /tmp/overlays
  none                      4.5G    484.2M      4.0G  11% /tmp/shaders
  ```
  
  flash is where a lot of icons are stored, and the system too. Don't forget to backup everything before manipulating stuff ! 
  You can change the boot logo by replacing both logo_kernel.bmp and logo.bmp from the /flash directory

- Issues when trying to reconnect to ssh :
  ```cmd
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
  Someone could be eavesdropping on you right now (man-in-the-middle attack)!
  It is also possible that a host key has just been changed.
  The fingerprint for the ED25519 key sent by the remote host is
  SHA256:CEQJa/t5qcg7vdVJHMRoA5KngqS+q05PuMAQzFQBrpc.
  Please contact your system administrator.
  Add correct host key in C:\\Users\\XXXX/.ssh/known_hosts to get rid of this message.
  Offending ECDSA key in C:\\Users\\XXXX/.ssh/known_hosts:3
  Host key for 192.168.7.2 has changed and you have requested strict checking.
  Host key verification failed.

  ```
  -> solution : `ssh-keygen -R 192.168.7.2` will solve this issue

- ping replies with "General failure" (Windows, not a timeout) ?
  -> your packets are not even leaving the PC. Typical culprit: a VPN with a kill-switch (e.g. WireGuard's "Block untunneled traffic") blocking all non-tunnel traffic. Disable the kill-switch or the VPN and try again. Quick check: `ping 1.1.1.1` works but `ping 192.168.7.2` fails with "General failure".

- unable to ping ?
    try to check if you're able to access the shell. if not, there is an issue. try
    `netstat -lntu`
  where you should get an answer like
  ```
  tcp        0      0 127.0.0.1:1234          0.0.0.0:*               LISTEN
  tcp        0      0 192.168.7.1:22          0.0.0.0:*               LISTEN
  etc...
  ```
  You need the two tcp connections. because one is local and the other is shared with the computer, allowing the ssh server to be connected to from the computer



# What's next ? 
- ~~a more presentable script (like displaying the ip on the console's display)~~ -> DONE: the script now shows a fullscreen info screen (`icons/ssh_info.png` via `ffplay`) with the IPs and credentials, with a plain-text fallback to `/dev/console`.
- run the server in the background and let the console stay usable while the server is running
- make the scripts less hard-coded with a config.conf file for the path of the adapter, etc... 
- An easy installer for ArkOS for that system to replace EmuElec

# Changes in this fork / PR
- Fixed `gamelist.xml` pointing to `usb_over_ethernet.sh` while the actual script is `ssh_over_usb.sh` (the port could not launch).
- Added `ports/SSH over USB.sh` launcher that auto-detects the roms root (`/storage/roms`, `/roms`, ...), so unzipping to the SD root is enough for the port to appear in EmulationStation (tested on an R36Max, EmuELEC 4.7).
- Connection info screen instead of a black screen (see above).
- Best-effort `scp` symlink from `dropbearmulti` so legacy `scp -O` transfers can work.
- README: corrected the PC/console IPs in the `netsh` example (PC is .1, console is .2), documented clean exit via `reboot`, file transfers, and the VPN kill-switch pitfall.
