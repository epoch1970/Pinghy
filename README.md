# Pinghy
An inflatable rescue wireless access point for Raspberry Pis made for RaspiOS.

## About this project
This project is in the public domain. Please make it your own.

Many users of Raspberry Pi SBCs are new to installing an OS to an embedded platform, and/or deploy their Raspberry Pis without screen and keyboard. These circumstances can lead less experienced users to lose access to their own machine.

Pinghy uses the wireless interface built in many models of Raspberry Pi to setup an open access point on demand, allowing users to reach their Raspberry Pi with ease. The created access point is open, no password required.

Pinghy responds to inputs from the local user, via a button wired to the built in GPIO interface of Raspberry Pi, or via keyboard keystrokes. User proximity with the machine is made a requirement since the open wireless access point creates a security risk in the vicinity of the machine.<br/>
Note: In this prototype it is possible to launch the Pinghy executable remotely, from an SSH session for example, and start the access point. This is **not** desirable.

Pinghy alerts all local and remote users of the machine when the access point is started and stopped:
 - For local users, LEDs on the platform blink as long as the access point is running.
 - CLI users logged on VTs or via SSH receive start and stop messages via `wall`
 - Users with an active graphical desktop session receive start and stop Desktop notifications

Pinghy is suited to transient and light use, such as connecting to a machine in order to fix its network connection, or providing a captive network for a few wireless sensors. Pinghy doesn't provide a general purpose wireless access point. It's a dinghy, not a battleship.

## About the repository
The original portions of Pinghy are written in shell (dash on RaspiOS). The code ties together a number a number of software packages preinstalled on RaspiOS: `dhcpcd`, `systemd-networkd`, `triggerhappy`, `sudo`, `ip-netns`, `wpa_supplicant`.<br/>
To use desktop notifications, 2 extra packages have to be installed on top of the Dekstop version of RaspiOS: `xfce4-notifyd` (server), `libnotify-bin` (CLI client).

Pinghy is activated by user inputs via `triggerhappy`. Pinghy handles itself: *i.* the configuration of the wireless phy according to the command received or to the current state of the wireless access point, *ii.* sending feedback to local and remote users of the machine. All the rest is done by `dhcpcd` (L2 network configuration, via `wpa_supplicant`) and `systemd-networkd` (L3 network configuration.)

To make state changes on the wireless interface easier to manage for the OS, Pinghy exports the wireless phy to a temporary namespace, reconfigures it within the namespace, and brings the phy back to the default linux namespace.
<br/>Processes running on RaspiOS see the wireless interface disappear and then come back, as if an USB adapter was removed and (a slighly different one) was added. Such events are handled in a robust manner by Linux, making Pinghy repeatable enough for button control.

Pinghy's state depends on a single information: presence or absence of a well-known wireless interface called `rpi0`. If present Pinghy can be stopped, if absent it can be started. State is assessed every time `pinghy.sh` runs. The special name `rpi0` is hardcoded throughout.

To install Pinghy to a suitable Raspberry Pi running RaspiOS, you'll need to copy files in this repository to `/opt/pinghy` on the target machine. Configuration files or fragments for the various RaspiOS packages are found in `/opt/pinghy/resources`. See also the `install_sh` convenience script.<br/>
Page [Install](./install.md) goes through the process of installing and testing Pinghy.

