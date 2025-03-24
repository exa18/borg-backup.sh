#!/bin/sh
#
# borg-backup.sh - BorgBackup shell script
#
# Copyright (c) 2017 Thomas Hurst <tom@hur.st>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
###############################################################################
#
# Synopsis:
#
# $ touch /etc/borg-backup.conf && chmod go-rw /etc/borg-backup.conf
# $ cat >>/etc/borg-backup.conf
# TARGET=backup@host:/backups
# PASSPHRASE='incorrect zebra generator clip'
# PASSPHRASE_homes='incorrect zebra generator clip'
# BACKUPS='homes etc'
# BACKUP_homes='/home -e /home/bob/.trash'
# BACKUP_etc='/etc'
# # (also available: COMPRESSION, PRUNE
# ^D
# $ borg-backup.sh init
# $ borg-backup.sh create
# $ borg-backup.sh list
# $ borg-backup.sh help
# $ CONFIG=/etc/another-borg-backup.conf borg-backup.sh init

set -eu

BORG_BACKUP_SH_VERSION="0.8.0"
SH="${0##*/}"

: "${BORG:=/usr/local/bin/borg}"
: "${CONFIG:=/etc/borg-backup.conf}"
COMPRESSION='zstd'
PRUNE='-H 24 -d 14 -w 8 -m 6'
COMPACT_THRESHOLD='10'
SUFFIX=".borg"

err() {
	echo "$@" 1>&2
	exit 78
}

usage() {
	echo
	echo "* ${SH%%.*} * $BORG_BACKUP_SH_VERSION *"
	echo
	echo "Configuration:"
	echo "  Borg:        $BORG"
	echo "  Config:      $CONFIG"
	echo "  Location:    $TARGET"
	echo "  Compression: $COMPRESSION"
	echo "  Suffix:      $SUFFIX"
	echo "  Backups:     $BACKUPS"
		for B in $BACKUPS; do
			eval "DIRS=\${BACKUP_${B}-}"
			[ -n "$DIRS" ] && echo "  | ${B}: ${DIRS}"
		done
	[ -z "${PASSPHRASE-}" ] && h="none" || h="repokey"
	echo "  Encryption:  $h"
		for B in $BACKUPS; do
			eval "THIS_PASSPHRASE=\${PASSPHRASE_${B}-}"
			[ -n "${THIS_PASSPHRASE-}" ] && echo "  | ${B}: ***"
		done
	echo "  Pruning:     $PRUNE"
		for B in $BACKUPS; do
			eval "THIS_PRUNE=\${PRUNE_${B}-}"
			[ -n "$THIS_PRUNE" ] && echo "  | ${B}: ${THIS_PRUNE}"
		done     
	echo
	echo "Usage:"
	echo " $SH help"
	echo " $SH init [BACKUP]"
	echo " $SH create [BACKUP]"
	echo " $SH list [BACKUP]"
	echo " $SH check [BACKUP]"
	echo " $SH quickcheck [BACKUP]"
	echo " $SH repocheck [BACKUP]"
	echo " $SH prune [BACKUP]"
	echo " $SH compact [BACKUP]"
	echo " $SH break-lock [BACKUP]"
	echo " $SH extract BACKUP [borg extract command]"
	echo " $SH info BACKUP ARCHIVE"
	echo " $SH delete BACKUP ARCHIVE"
	echo " $SH borg BACKUP [arbitrary borg command-line]"
	echo " $SH changepass BACKUP PASSPHRASE"
	echo
	echo " e.g: $SH borg etc extract ::etc-2017-02-21T20:00Z etc/rc.conf --stdout"
	echo
	echo "Use a BACKUP name of '--' to apply a 'borg' command to all backups"
	exit "$1"
}

[ -z "$CONFIG" ] && err "CONFIG unset"
[ -r "$CONFIG" ] || err "CONFIG $CONFIG unreadable"
[ -f "$CONFIG" ] || err "CONFIG $CONFIG not a regular file"

# shellcheck disable=SC1090
. "$CONFIG"

[ -e "$BORG" ]          || err "$BORG not executable (see https://borgbackup.readthedocs.io/en/stable/installation.html)"
[ -z "$PRUNE" ]         && err "PRUNE not set (e.g. '-H 24 -d 14 -w 8 -m 6')"
[ -z "${TARGET-}" ]     && err "TARGET not set (e.g. 'backup@host:/backup/path')"
[ -z "${BACKUPS-}" ]    && err "BACKUPS not set (e.g. 'homes etc')"

for B in $BACKUPS; do
	eval "DIRS=\${BACKUP_${B}-}"
	[ -z "${DIRS}" ] && err "BACKUP_${B} not set (e.g. '/home/bla -e /home/bla/.foo')"
done

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%MZ")

nargs=$#
cmd=${1-}
backup=${2-}
if [ "$#" -gt 0 ]; then shift; fi
if [ "$#" -gt 0 ]; then shift; fi

rc=0
for B in $BACKUPS; do
	if [ "$nargs" -eq 1 ] || [ "$backup" = "--" ] || [ "$backup" = "$B" ] ; then
		export BORG_REPO="${TARGET}/${B}${SUFFIX}"
		eval "DIRS=\$BACKUP_${B}"
		eval "THIS_PASSPHRASE=\${PASSPHRASE_${B}-\${PASSPHRASE-}}"
		if [ -z "${THIS_PASSPHRASE-}" ];then
			REPOKEY="none"
		else
			REPOKEY="repokey"
			export BORG_PASSPHRASE="$THIS_PASSPHRASE"
		fi
		case $cmd in
			init)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG init --encryption=$REPOKEY || rc=$?
			;;
			create)
				[ "$nargs" -gt 2 ] && usage 64
				# shellcheck disable=SC2086
				$BORG create --exclude-caches --compression=${COMPRESSION} -v -s ::"${B}-${TIMESTAMP}" $DIRS || rc=$?
			;;
			list)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG list || rc=$?
			;;
			check)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG check -v || rc=$?
			;;
			quickcheck)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG check -v --last=1 || rc=$?
			;;
			repocheck)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG check -v --repository-only || rc=$?
			;;
			prune)
				[ "$nargs" -gt 2 ] && usage 64
				eval "THIS_PRUNE=\${PRUNE_${B}-\${PRUNE}}"
				# shellcheck disable=SC2086
				$BORG prune -sv $THIS_PRUNE || rc=$?
			;;
			compact)
				[ "$nargs" -gt 2 ] && usage 64
				# shellcheck disable=SC2086
				$BORG compact -v --threshold "${COMPACT_THRESHOLD}" || rc=$?
			;;
			info)
				[ "$nargs" -ne 3 ] && usage 64
				$BORG info ::"$1" || rc=$?
			;;
			delete)
				[ "$nargs" -ne 3 ] && usage 64
				$BORG delete -s -p ::"$1" || rc=$?
			;;
			extract)
				[ "$nargs" -lt 3 ] && usage 64
				$BORG extract "$@" || rc=$?
			;;
			break-lock)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG break-lock || rc=$?
			;;
			changepass)
				NEW_PASSPHRASE="${1-}"
				[ "$nargs" -ne 3 ] && [ -z "${THIS_PASSPHRASE-}" ] && [ -z "${NEW_PASSPHRASE-}" ] && usage 64
				export BORG_NEW_PASSPHRASE="$NEW_PASSPHRASE"
				t="$(pwd)/borgtemp"
				cat $CONFIG | grep -v "PASSPHRASE_${B}=" > $t
				echo "PASSPHRASE_${B}='${NEW_PASSPHRASE}'" >> $t
				sudo mv $t $CONFIG
				$BORG key change-passphrase || rc=$?
			;;
			borg)
				[ "$nargs" -lt 2 ] && usage 64
				$BORG "$@" || rc=$?
			;;
			help|--help|-h)
				usage 0
			;;
			*)
				usage 64
		esac
	fi
done

exit $rc

