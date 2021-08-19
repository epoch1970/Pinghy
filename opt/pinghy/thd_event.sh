#!/bin/sh
# Part of Pinghy - https://github.com/epoch1970/Pinghy.git
# This script is called by Triggerhappy. It reacts if called $e_cn consecutive
# times within $e_ds secs of each call.

# shellcheck shell=dash
set -o errexit -o nounset
exec 2>/dev/null

e_cn=2; e_ds=2 # Threshold: at least 3 calls 2 secs apart of each other.

cleanup(){
	# Flag file: last uptime + calls counter
	[ -f /run/lock/pinghy.event ] || echo 0 0 > /run/lock/pinghy.event
}
trap cleanup EXIT

( flock -n 5
	# Don't bother if the platform is unsupported
	[ -f /run/pinghy/support ] && [ "$(cat /run/pinghy/support)" -ne 1 ] && exit
	# Process input events
	curr="$(cat /proc/uptime)"; curr=${curr%%.*}
	set -- $(cat /run/lock/pinghy.event); cnt=$2
	delta=$(( curr - $1 ))
	if [ ${delta} -gt ${e_ds} ]; then
		cnt=0 # too long, reset count
	else
		cnt=$(( cnt + 1 ))
	fi
	if [ ${cnt} -ge ${e_cn} ]; then
		# Requires /etc/sudoers.d/020-pinghy-from-nobody
		sudo /opt/pinghy/pinghy.sh
		cnt=0
	fi
	echo "${curr} ${cnt}" > /run/lock/pinghy.event
) 5>/run/lock/pinghy.lock

exit
