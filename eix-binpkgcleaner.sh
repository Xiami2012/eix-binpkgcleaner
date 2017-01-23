#!/bin/bash
#
# Gentoo obsolete binary packages smart cleaner
#
# Author: Xiami <i@f2light.com>
#

cleanup() {
	rm -f ${tmpfile:?tmpfile_null}
	rm -f ${tmpfile2:?tmpfile2_null}
	rm -f ${tmp_rpcache:?tmp_rpcache_null}
	rm -rf ${tmpdir:?tmpdir_null}
}

e() {
	echo "Aborted" >&2
	cleanup
	exit 1
}

# `portageq` is the slowest op in xpak_hash
# do a simple hash cache here to solve the perf hotpot
# get_repo_path <repo_name>
get_repo_path() {
	declare -A repo_paths
	source $tmp_rpcache

	# Fresh fetch
	if [ -z "${repo_paths[$1]}" ]; then
		local rp=`portageq get_repo_path / $1`
		repo_paths[$1]=${rp:-fault}
		echo "repo_paths[$1]=${rp:-fault}" >> $tmp_rpcache
	fi
	if [ "${repo_paths[$1]}" = "fault" ]; then
		echo "repository $(<$tmpdir/repository) obsoleted? try running me with -u." >&2
		return 1
	fi
	echo ${repo_paths[$1]}
	return 0
}

isatty() {
	[ -t 0 ] && [ -t 1 ] && return 0 || return 1
}

# xpak_hash <filnam>
xpak_hash() {
	rm -rf ${tmpdir:?tmpdir_null}
	mkdir -p $tmpdir
	# Unpack XPAK info
	qtbz2 -sxO $1 | qxpak -x -d $tmpdir -
	# Diff ebuild in binary package and ebuild in portage tree
	portdir=`get_repo_path $(<$tmpdir/repository)` || return 2
	# Let shell auto-complete this :)
	ebuild_in_tree=`ls $portdir/$(<$tmpdir/CATEGORY)/*/$(<$tmpdir/PF).ebuild`
	ebuild_in_binpkg=`ls $tmpdir/*.ebuild`
	# Ignore keywords and comment changes
	diff -q <(grep -vEe "^#|KEYWORDS=" $ebuild_in_binpkg) <(grep -vEe "^#|KEYWORDS=" $ebuild_in_tree) > /dev/null || return 1
	# Print CPF and USE hash (SHA256 truncated to 128-bit)
	echo -n "$(<$tmpdir/CATEGORY)/$(<$tmpdir/PF) "
	sha256sum $tmpdir/USE | head -c 32
	return 0
}

prog=`realpath $BASH_SOURCE`
wd=`dirname $prog`

tmpfile=`mktemp /tmp/eix-binpkgcleaner.XXX` || e
tmpfile2=`mktemp /tmp/eix-binpkgcleaner.XXX` || e
tmp_rpcache=`mktemp /dev/shm/eix-binpkgcleaner.XXX` || e
tmpdir=`mktemp -d /tmp/eix-binpkgcleaner.XXX` || e
pkgdir=`portageq pkgdir`

trap "cleanup; exit 1" INT TERM

# Support only 1 optional argument, do not use getopt now
if [ "$1" == "-u" ]; then
	echo "Updating portage.eix..." >&2
	if isatty; then
		eix-update || e
	else
		eix-update >/dev/null 2>&1 || e
	fi
fi

echo "Filtering binary packages (low version in slot * keyword)..." >&2
# Fetch what to be preserved filtered by slot and keyword
ls `eix --binary -xl | awk -f $wd/eix-binpkgcleaner.awk` | sort > $tmpfile || e

echo "Filtering binary packages (ebuild non-keyword update + duplicate USE binpkg)..." >&2
while read -r; do
	# Packages, Packages.gz
	if [ "${REPLY%%.tbz2}" = "$REPLY" ] && [ "${REPLY%%.xpak}" = "$REPLY" ]; then
		echo $REPLY
		continue
	fi
	if ! cpv_usehash=(`xpak_hash $REPLY`); then
		echo "${REPLY#$pkgdir/} deprecated due to ebuild update" >&2
		continue
	fi
	if [ "$cpv" != "${cpv_usehash[0]}" ]; then
		cpv=${cpv_usehash[0]}
		unset use_hashes
		declare -A use_hashes
		use_hashes[${cpv_usehash[1]}]=1
		echo $REPLY
	elif [ "${use_hashes[${cpv_usehash[1]}]}" = 1 ]; then
		echo "${REPLY#$pkgdir/} deprecated due to duplicate USE binpkg exists" >&2
	else
		use_hashes[${cpv_usehash[1]}]=1
		echo $REPLY
	fi
done < $tmpfile > $tmpfile2

# Convert to file list for rm
fillst=`diff -u <(find ${pkgdir} -type f | sort) $tmpfile2 |
	tail -n +3 | grep -e "^-" | sed -e "s/^-//"`

if isatty; then
	if [ -n "$fillst" ]; then
		echo -e "\e[38;5;220;1mThose file are to be deleted:\e[0m"
		echo "$fillst" | sed -e "s/^${pkgdir//\//\\\/}\///"
		echo -en "\n\e[38;5;118mIf confirmed, type \"y\" and press Enter.\e[0m\n> "

		read -er
		if [ "$REPLY" = "y" ]; then
			rm -vf $fillst
			find $pkgdir -type d -empty -delete
			emaint -f binhost
		fi
	else
		echo -e "\e[38;5;46mPackages tree is already clean."
	fi
else
	echo "$fillst"
fi

cleanup
