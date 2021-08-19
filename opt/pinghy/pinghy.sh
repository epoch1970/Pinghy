#!/bin/sh
# Part of Pinghy - https://github.com/epoch1970/Pinghy.git
# Enables/disables the virtual AP interface feature in built-in wireless phy
# of select models of Raspberry Pi
# Accepts optional argument 'on', 'off' or 'toggle' (default)
# Behaviour of this script can be adjusted using file preferences_sh
#
# shellcheck shell=dash disable=SC1091
set -o nounset -o errexit
exec 2>/dev/null

cleanup(){
	# Cleanup lingering processes and delete ns
	if pids="$(ip netns pids tmp-$$ 2>/dev/null)"; then
		echo "${pids:-}" | xargs --no-run-if-empty kill
		ip netns del tmp-$$ >/dev/null
	fi
}
trap cleanup EXIT

store='/run/pinghy'; uap='rpi0'; sta=; phy=; state=
[ -f '/opt/pinghy/preferences_sh' ] && . '/opt/pinghy/preferences_sh'
[ -d "${store}" ] || mkdir -p "${store}"

_notif_msg(){
	case "${1}-${2}" in # $1=1: on, 0: off $2=cli, gui
		'1-cli') cat <<EOF
Pinghy - Wireless access to this Raspberry Pi is now open!
         SSID: $(cat ${store}/ssid)
         * This is a security risk * Close access as soon as possible *
EOF
		;;
		'0-cli') cat <<EOF
Pinghy - Wireless access to this Raspberry Pi is now closed
EOF
		;;
		'1-gui') cat <<EOF

Wireless access to this Raspberry Pi is now open!
SSID: $(cat ${store}/ssid)
• This is a security risk • Close access as soon as possible •
EOF
		;;
		'0-gui') cat <<EOF

Wireless access to this Raspberry Pi is now closed
EOF
		;;
	esac
}
_prep_wpaconf(){
	local ssid="${p_ap_ssid:-}"
	if [ -z "${ssid}" ]; then
		local sn; local h
		sn="$(vcgencmd otp_dump | grep '^28:')"; sn="${sn#28:????*}"; sn="${sn:-0000}"
		h="$(hostname -s)"; h="${h:-RaspiOS}"
		ssid="$h-$(cat ${store}/model)-$sn"
	fi
	echo "${ssid}" > "${store}/ssid"
	sed -e "s/ssid=.*/ssid=$(echo -n ${ssid} | xxd -p)/" \
		/opt/pinghy/resources/wpa_supplicant-rpi0.in > "${store}/wpa_supplicant-rpi0.conf"
}
_hide_phy(){
	# Create network namespace, send phy to ns. L2 and L3 get reset
	ip netns add tmp-$$
	iw "${phy}" set netns name tmp-$$
	# Get current uptime and min phy export duration in secs
	local now; now="$(cat /proc/uptime)"; now="${now%%.*}"
	echo "$(( now + ${p_ns_quiesce:-5} ))"
}
_reveal_phy(){
	# Sleep if needed
	local now; now="$(cat /proc/uptime)"; now="${now%%.*}"
	[ "${now}" -lt "${1:-0}" ] && sleep $(( ${1} - now ))
	# Send back our phy and its interface(s) to the root namespace. L2 and L3 get configured
	ip netns exec tmp-$$ iw "${phy}" set netns 1 >/dev/null 2>&1
}
_wifs_disco(){
	local iff="/sys/class/net/${uap}"; local hint=
	if [ -d "${iff}" ]; then # AP on, $uap exists: $uap -> phy? -> sta?
		state=1
		phy="$(cat ${iff}/phy80211/name)"
		for iff in "/sys/class/ieee80211/${phy}/device/net/"*; do
			[ -d "${iff}" ] || continue
			hint="${iff##*/}"
			case "${hint}" in
				"${uap}") true ;; # noop, continue
				*) sta="${hint}"
				   break
				;;
			esac
		done
	else # AP off, $uap doesn't exist: sta? -> phy? -> $uap
		state=0
		for iff in /sys/class/net/*; do
			[ -d "${iff}/wireless" ] || continue
			hint="$(cat ${iff}/device/uevent)"; hint="${hint#*MODALIAS=}"
			case "${hint}" in
				'sdio:c00v02D0dA9A6') # Apparently same for all Pi models?
					sta="$(basename ${iff})"; phy="$(cat ${iff}/phy80211/name)"
					break
				;;
			esac
		done
	fi
	{ [ -n "${phy}" ] && [ -n "${sta}" ] && [ -n "${state}" ] ; } || return 1
}
_pi_disco(){
	local s=; local m=; local c
	# https://www.raspberrypi.org/documentation/computers/raspberry-pi.html#raspberry-pi-revision-codes
	c="$(vcgencmd otp_dump | grep '^30:')"; c="${c#30:*}"; c="$(( 0x${c} ))"; c="$(( c & 4080 ))"; c="$(( c >> 4 ))"; c="$(printf '%x' ${c})"
	case "${c}" in
		'8')  m='Pi3B'; s=1 ;;
		'c')  m='Pi0w'; s=1 ;;
		'd')  m='Pi3B+'; s=1 ;;
		'e')  m='Pi3A+'; s=1 ;;
		'11') m='Pi4B'; s=1 ;;
		'13') m='Pi400'; s=1 ;;
	esac
	echo "${m:-unknown}" > "${store}/model"
	echo "${s:-0}" > "${store}/support"
}
leds_ctl(){
	[ "${p_ui_leds:-1}" -eq 1 ] || return 0
	for led in 'act' 'pwr'; do
		case "${1}" in # 1: on, 0: off
			'1')	[ -d "/proc/device-tree/leds/${led}" ] || continue
				local l; local t
				l="$(cat /proc/device-tree/leds/${led}/label)"
				t="$(cat /sys/class/leds/${l}/trigger)"; t=${t##*[}; t=${t%%]*}
				[ -d "${store}/leds/${led}" ] || mkdir -p "${store}/leds/${led}"
				echo "${l}" > "${store}/leds/${led}/label"
				echo "${t}" > "${store}/leds/${led}/trigger"
				echo 'timer' > "/sys/class/leds/${l}/trigger"
				echo 200 > "/sys/class/leds/${l}/delay_on"
				echo 200 > "/sys/class/leds/${l}/delay_off"
				echo 1 > "/sys/class/leds/${l}/brightness"
				sleep .200 # staggered blinking?
			;;
			'0')	[ -d "${store}/leds/${led}" ] || return 0
				local l; l="$(cat ${store}/leds/${led}/label)"
				cat "${store}/leds/${led}/trigger" > "/sys/class/leds/${l}/trigger"
				echo 1 > "/sys/class/leds/${l}/brightness"
			;;
		esac
	done
}
notifs_ctl(){
	[ "${p_ui_msg:-1}" -eq 1 ] || return 0
	[ "${p_ui_msg_cli:-1}" -eq 1 ] && { wall "$(_notif_msg ${1} cli)" 2>/dev/null || true ; }
	# GUI notifs, a bit more complex than wall.
	[ "${p_ui_msg_gui:-0}" -eq 0 ] && return 0
	while read -r line; do
		id="${line%% *}"
		local cnt=0; local disp=; local uid=; local user=
		while read -r line; do
			case "${line:-}" in
				'Display='*) disp="${line#*=}" ;;
				'User='*) uid="${line#*=}" ;;
				'Name='*) user="${line#*=}" ;;
				'Class=user'|'Active=yes') cnt="$((cnt + 1))" ;;
			esac
		done <<EOF
		$(loginctl show-session "${id}")
EOF
		{ [ -n "${user}" ] && [ -n "${uid}" ] && [ -n "${disp}" ] && [ "${cnt}" -eq 2 ] ; } || continue
		local icon; icon="${p_ui_msg_gui_icon:-gtk-dialog-info}"
		sudo -u "${user}" \
		DISPLAY="${disp}" DBUS_SESSION_BUS_ADDRESS=unix:path="/run/user/${uid}/bus" \
		/usr/bin/notify-send -i "${icon}" -u critical "Pinghy - $(date)" "$(_notif_msg ${1} gui)"
	done <<EOF
	$(loginctl --no-legend --no-pager list-sessions)
EOF
}
rpi0_ctl(){
	local when=
	case "${1}" in # 1: on, 0: off
		'1')	when="$(_hide_phy)"
			ip netns exec tmp-$$ iw phy "${phy}" interface add "${uap}" type __ap >/dev/null
			_reveal_phy "${when}"
		;;
		'0')	when="$(_hide_phy)"
			ip netns exec tmp-$$ iw dev "${uap}" del >/dev/null
			_reveal_phy "${when}"
		;;
	esac
}
state_ok(){
	[ -f "${store}/support" ] || _pi_disco
	[ "$(cat ${store}/support)" -eq 1 ] || return 1
	_wifs_disco || return 1
	[ "${state}" -eq 1 ] && return 0 # Currently on, don't check further
	# FIXME AP will fail if a p2p interface is active. FIXME detect.
	local ok=0
	while read -r line; do
		case "${line}" in
			'type managed') ok=1; break ;;
		esac
	done <<EOF
	$(iw "${sta}" info)
EOF
	[ "${ok}" -eq 1 ] || return 1
	# rfkill - 0: unblocked 1: blocked
	[ "$(cat /sys/class/ieee80211/${phy}/rfkill*/hard)" -eq 0 ] || return 1
	local idx; idx="$(cat /sys/class/ieee80211/${phy}/rfkill*/index)"
	echo 0 > "/sys/class/ieee80211/${phy}/rfkill${idx}/soft"
	{ [ -f "${store}/wpa_supplicant-rpi0.conf" ] && [ -e "${store}/ssid" ] ; } || _prep_wpaconf
}

# Only run: 1. on select platforms, 2. when built-in wireless is activated,
# 3. when Rfkill hard blocking (button) is not set, 4. when the wireless
# interface is in a compatible state (~idle or client mode)
state_ok || exit 0

op=-1
case "${state}-${1:-toggle}" in
	'0-on') op=1 ;;
	'1-off') op=0 ;;
	"${state}-toggle") op=$(( 1 ^ state )) ;;
esac

{ [ "${op}" -eq 0 ] || [ "${op}" -eq 1 ] ; } || exit 0 # Skip no-ops
rpi0_ctl "${op}"; leds_ctl "${op}"; notifs_ctl "${op}"

exit $?
