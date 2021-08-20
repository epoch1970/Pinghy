# Install and test scenario for Pinghy

## Prologue
`odessa` is a Mac desktop machine. `raspberrypi` is a Raspberry Pi 3B running RaspiOS. A LAN (192.168.1.0/24) is available over ethernet and wireless.

## Install
 - Using Raspberry Pi Imager, install RaspiOS Desktop or Lite to an SD. Enable SSH. *Do not configure wireless at all.*
 - Insert the SD in the Raspberry Pi, boot it and connect ethernet to be able to transfer Pinghy over to the Pi:
```
odessa:~ me$ scp pinghy.tar pi@raspberrypi.local:~/
...
pi@raspberrypi.local's password: 
pinghy.tar                                    100%  110KB 784.0KB/s   00:00    
```
 - Login to the Pi (over ethernet), take a look then install Pinghy:
```
odessa:~ me$ ssh pi@raspberrypi.local
pi@raspberrypi.local's password: 
Linux raspberrypi 5.10.17-v7+ #1414 SMP Fri Apr 30 13:18:35 BST 2021 armv7l

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Wed Aug 18 12:54:51 2021

Wi-Fi is currently blocked by rfkill.
Use raspi-config to set the country before use.

pi@raspberrypi:~ $ sudo su
root@raspberrypi:/home/pi# mv pinghy.tar /opt
root@raspberrypi:/home/pi# cd /opt
root@raspberrypi:/opt# tar xvf pinghy.tar 
pinghy/
pinghy/thd_event.sh
pinghy/resources/
pinghy/resources/020-pinghy-from-nobody
pinghy/resources/dhcpcd_conf
pinghy/resources/wpa_supplicant-rpi0.in
pinghy/resources/pinghy-rpi0.network
pinghy/resources/pinghy-trigger.conf
pinghy/resources/config_txt
pinghy/resources/install_sh
pinghy/raspi-config_mod
pinghy/pinghy.sh
pinghy/preferences_sh

root@raspberrypi:/opt# cd pinghy
root@raspberrypi:/opt/pinghy# cat preferences_sh 
# Part of Pinghy - https://github.com/epoch1970/Pinghy.git
# NOTE: This file is shell code sourced by pinghy.sh
#
p_ui_leds=1	# Flash platform LEDs to show AP on or off.
		# bool. Default on (1)
...

root@raspberrypi:/opt/pinghy# cat resources/install_sh 
#!/bin/sh -x
srcdir='/opt/pinghy/resources'
[ -d "${srcdir}" ] || exit 1
[ "$(id -u)" -eq 0 ] || { echo "Run me as root."; exit 1; }
...

root@raspberrypi:/opt/pinghy# ./resources/install_sh 
+ srcdir=/opt/pinghy/resources
+ [ -d /opt/pinghy/resources ]
+ id -u
+ [ 0 -eq 0 ]
+ ln -s /opt/pinghy/resources/020-pinghy-from-nobody /etc/sudoers.d/
...
```

## Test Pinghy
- Once install is complete, shutdown the Pi, *disconnect the ethernet cable*, connect an USB keyboard to the Pi.<br/>
If you wish to connect a GPIO button, **remove power from the Pi** before accessing the GPIO pins.<br/>
 - Power on the Pi. Once booted, hit the "Home" key on the keyboard or the GPIO button 3 or 4 times in a row. LEDs on the Raspberry Pi will start flashing within seconds. To stop Pinghy, you can use the same key sequence; LEDs will revert to their previous configuration.
 - With Pinghy started, connect to an open SSID named as `raspberrypi-Pi3B-4c1b` (host name, model name, part of serial number) on your Desktop machine. Then connect to the Pi via SSH over this wireless network:

```
odessa:~ me$ ping raspberrypi.local
PING raspberrypi.local (10.0.0.1): 56 data bytes
64 bytes from 10.0.0.1: icmp_seq=0 ttl=64 time=4.835 ms
^C
--- raspberrypi.local ping statistics ---
1 packets transmitted, 1 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 4.835/4.835/4.835/0.000 ms

odessa:~ me$ ssh pi@raspberrypi.local
...
pi@raspberrypi.local's password: 
Linux raspberrypi 5.10.17-v7+ #1414 SMP Fri Apr 30 13:18:35 BST 2021 armv7l

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Wed Aug 18 13:13:38 2021
pi@raspberrypi:~ $ iwconfig 
lo        no wireless extensions.

eth0      no wireless extensions.

wlan0     IEEE 802.11  ESSID:off/any  
          Mode:Managed  Access Point: Not-Associated   Tx-Power=31 dBm   
          Retry short limit:7   RTS thr:off   Fragment thr:off
          Power Management:on
          
rpi0      IEEE 802.11  Mode:Master  Tx-Power=31 dBm   
          Retry short limit:7   RTS thr:off   Fragment thr:off
          Power Management:on
          
pi@raspberrypi:~ $ rfkill
ID TYPE      DEVICE      SOFT      HARD
 0 wlan      phy0   unblocked unblocked
 1 bluetooth hci0   unblocked unblocked

pi@raspberrypi:~ $ iw reg get
global
country 00: DFS-UNSET
	(2402 - 2472 @ 40), (N/A, 20), (N/A)
	(2457 - 2482 @ 20), (N/A, 20), (N/A), AUTO-BW, PASSIVE-SCAN
	(2474 - 2494 @ 20), (N/A, 20), (N/A), NO-OFDM, PASSIVE-SCAN
	(5170 - 5250 @ 80), (N/A, 20), (N/A), AUTO-BW, PASSIVE-SCAN
	(5250 - 5330 @ 80), (N/A, 20), (0 ms), DFS, AUTO-BW, PASSIVE-SCAN
	(5490 - 5730 @ 160), (N/A, 20), (0 ms), DFS, PASSIVE-SCAN
	(5735 - 5835 @ 80), (N/A, 20), (N/A), PASSIVE-SCAN
	(57240 - 63720 @ 2160), (N/A, 0), (N/A)
```
 - Start `raspi-config_mod` to configure wireless and connect the Raspberry Pi to a local network. `raspi-config_mod` is a copy of the original `raspi-config` script utility, with a couple of changes to make it deal with the special AP interface `rpi0`:
```
pi@raspberrypi:~ $ cd /opt/pinghy/
pi@raspberrypi:/opt/pinghy $ sudo ./raspi-config_mod
```
 - Within raspi-config_mod, configure menus *1>S1*: WiFi country code, ssid/password. Then select *Finish* and agree to reboot.
 - Reset the connection of your Desktop while the Pi reboots, then connect to it over the regular LAN:
```
odessa:~ me$ ping raspberrypi.local
PING raspberrypi.local (192.168.1.239): 56 data bytes
64 bytes from 192.168.1.239: icmp_seq=0 ttl=64 time=172.460 ms
^C
--- raspberrypi.local ping statistics ---
1 packets transmitted, 1 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 172.460/172.460/172.460/0.000 ms

odessa:~ me$ ssh pi@raspberrypi.local
...
pi@raspberrypi.local's password: 
Linux raspberrypi 5.10.17-v7+ #1414 SMP Fri Apr 30 13:18:35 BST 2021 armv7l

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Wed Aug 18 13:27:03 2021

pi@raspberrypi:~ $ iwconfig 
lo        no wireless extensions.

eth0      no wireless extensions.

wlan0     IEEE 802.11  ESSID:"LAN_SSID"  
          Mode:Managed  Frequency:2.437 GHz  Access Point: 01:02:03:04:05:06   
          Bit Rate=65 Mb/s   Tx-Power=31 dBm   
          Retry short limit:7   RTS thr:off   Fragment thr:off
          Power Management:on
          Link Quality=56/70  Signal level=-54 dBm  
          Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
          Tx excessive retries:0  Invalid misc:0   Missed beacon:0

pi@raspberrypi:~ $ iw reg get
global
country FR: DFS-ETSI
	(2402 - 2482 @ 40), (N/A, 20), (N/A)
	(5170 - 5250 @ 80), (N/A, 20), (N/A), AUTO-BW
	(5250 - 5330 @ 80), (N/A, 20), (0 ms), DFS, AUTO-BW
	(5490 - 5710 @ 160), (N/A, 27), (0 ms), DFS
	(57000 - 66000 @ 2160), (N/A, 40), (N/A)

```
EOF
