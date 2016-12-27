#!/usr/bin/gawk -f
#
# Gentoo obsolete binary packages smart cleaner awk script
#
# Only preserve latest version packages in each slot
#
# Example:
#   sys-apps/test:0 has sys-apps/test-0.1,sys-apps/test-0.2,sys-apps/test-0.99
#   sys-apps/test:1 has sys-apps/test-1.0
# This program will cleanup sys-apps/test-0.1,sys-apps/test-0.2,
# printing all latest packages in each slot.
#
# Usage:
#   List file patterns to preserve:
#     ls `eix --binary -xl | awk -f ./eix-binpkgcleaner.awk`
#
# Author: Xiami <i@f2light.com>
#

function debug3(statemsg)
{
	if (debug >= 3)
	{
		printf "state %s capturing line %d", statemsg, NR > "/dev/stderr"
	}
	if (debug >= 4)
	{
		printf ": %s", $0 > "/dev/stderr"
	}
	if (debug >= 3)
	{
		printf "\n" > "/dev/stderr"
	}
}

BEGIN \
{
	debug = ENVIRON["DEBUG"]
	if (debug == "") debug = 0
	scan_slot = ENVIRON["SCAN_SLOT"]
	if (scan_slot == "") scan_slot = 1
	scan_keyword = ENVIRON["SCAN_KEYWORD"]
	if (scan_keyword == "") scan_keyword = 1

	# Internal vars
	"portageq pkgdir" | getline pkgdir
	state = 0
}

# Package name
state == 0 && /^(*|\[.\]) / \
{
	debug3("find_pkg")
	split($0, result, " ")
	pkgname = result[2]
	if (debug >= 2) { printf "state 0->1, new pkgname = %s\n", pkgname > "/dev/stderr" }
	state = 1
	next
}

# Avail versions
state == 1 && /^ {5}Available versions:/ \
{
	debug3("find_title_avail_ver")
	if (debug >= 2) { printf "state 1->2, Available versions section found\n" > "/dev/stderr" }
	state = 2
	next
}

state == 2 && /^ {7}.*\{(tbz2|xpak)/ \
{
	debug3("find_one_binary_version")
	# Fetch keyword
	$0 = substr($0, 8)
	if (scan_keyword == 0 || substr($0, 1, 1) == " ")
	{
		kw = "stable"
	}
	else
	{
		switch ($1)
		{
			case /-/:
				kw = "fault"
				break
			case /\*/:
				kw = "missing"
				break
			case /~/:
				kw = "testing"
				break
			default:
				kw = "stable"
		}
	}
	# Fetch slot
	$0 = substr($0, 6)
	match($2, /\(([^/]*)(\/.*)?\)/, result)
	if (scan_slot == 1 && result[1, "start"])
	{
		slot = substr($2, result[1, "start"], result[1, "length"])
	}
	else
	{
		slot = 0
	}
	if (debug >= 1) { printf "found version %s for %s:%s at keyword %s\n", $1, pkgname, slot, kw > "/dev/stderr" }
	sks[slot][kw] = $1
	next
}

# End of this package
state == 2 && /^ {5}\w/ \
{
	debug3("find_end")
	for (i_slot in sks)
	{
		for (i_kw in sks[i_slot])
		{
			if (debug >= 1) { printf "preserve latest version %s for %s:%s at keyword %s\n", sks[i_slot][i_kw], pkgname, i_slot, i_kw > "/dev/stderr" }
			# tbz2
			tbz2_filnam = sprintf("%s/%s-%s.tbz2", pkgdir, pkgname, sks[i_slot][i_kw])
			cmd = sprintf("ls %s >/dev/null 2>&1", tbz2_filnam)
			if (system(cmd) == 0)
			{
				printf "%s\n", tbz2_filnam
			}
			# xpak
			pkgname_basename = pkgname
			sub(/.*\//, "", pkgname_basename)
			# NOTE: [0-9]* here is not used as a regexp, actually it acts as /[0-9].*/
			# This is enough to distinguish between 6.0-1.xpak and 6.0-r1-1.xpak
			xpak_filnam = sprintf("%s/%s/%s-%s-[0-9]*.xpak", pkgdir, pkgname, pkgname_basename, sks[i_slot][i_kw])
			cmd = sprintf("ls %s >/dev/null 2>&1", xpak_filnam)
			if (system(cmd) == 0)
			{
				printf "%s\n", xpak_filnam
			}
		}
	}
	delete sks
	if (debug >= 2) { printf "state 2->0, found unprocessable section %s\n", substr($1, 0, length($1) - 1) > "/dev/stderr" }
	state = 0
	next
}

END \
{
	printf "%s/Packages\n", pkgdir
	# For portage FEATURES compress-index
	printf "%s/Packages.gz\n", pkgdir
}
