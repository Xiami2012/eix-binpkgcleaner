#!/bin/bash
#
# Gentoo obsolete packages smart cleaner
#
# Author: Xiami <i@f2light.com>
#

e() {
	echo "Aborted" >&2
	exit 1
}

isatty() {
	[ -t 0 ] && [ -t 1 ] && return 0 || return 1
}

prog=`realpath $BASH_SOURCE`
wd=`dirname $prog`

tmpfile=`mktemp /tmp/eix-pkgcleaner.XXX`
PKGDIR=${PKGDIR:-/usr/portage/packages}

# Support only 1 optional argument, do not use getopt now
if [ "$1" == "-u" ]; then
	echo "Updating portage.eix..." >&2
	if isatty; then
		eix-update || e
	else
		eix-update >/dev/null 2>&1 || e
	fi
fi

echo "Filtering binary packages..." >&2
ls `eix --binary -xl | awk -f $wd/eix-pkgcleaner.awk` | sort > $tmpfile || e
fillst=`diff -u <(find ${PKGDIR} -type f | sort) $tmpfile |
	tail -n +3 | grep -e "^-" | sed -e "s/^-//"`

# Early remove tmpfile to avoid trap SIGINT when waiting for stdin
rm -f $tmpfile

if isatty; then
	if [ -n "$fillst" ]; then
		echo -e "\e[38;5;220;1mThose file are to be deleted:\e[0m"
		echo "$fillst" | sed -e "s/^${PKGDIR//\//\\\/}\///"
		echo -en "\n\e[38;5;118mIf confirmed, type \"y\" and press Enter.\e[0m\n> "

		read -r
		if [ "$REPLY" = "y" ]; then
			rm -vf $fillst
			emaint -f binhost
		fi
	else
		echo -e "\e[38;5;46mPackages tree is already clean."
	fi
else
	echo "$fillst"
fi