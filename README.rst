##############
eix-pkgcleaner
##############

************
Introduction
************
eix-pkgcleaner is a tool to do a job like eclean-pkg(from gentoolkit) but smarter.

It does clean jobs by 2 stages.

Stage 1
=======
For every package which have binary packages, by default,
it outputs all binary packages with latest version in each slot and each keyword [#keyword]_ ,
filtering out all lower versions.

Example (dev-vcs/git)
---------------------
Imagine you have binary versions below:

+----------+------+-------+--------+------+
| Version  | Slot | amd64 | ~amd64 | \*\* |
+==========+======+=======+========+======+
| 2.4.10   | Removed from portage tree    |
+----------+------+-------+--------+------+
| 2.4.11   | 0    |       | o      |      |
+----------+------+-------+--------+------+
| 2.5.5    | 0    |       | o      |      |
+----------+------+-------+--------+------+
| 2.7.3-r1 | 0    | o     |        |      |
+----------+------+-------+--------+------+
| 2.10.2   | 0    | o     |        |      |
+----------+------+-------+--------+------+
| 2.11.0   | 0    |       | o      |      |
+----------+------+-------+--------+------+
| 9999-r1  | 0    |       |        | o    |
+----------+------+-------+--------+------+
| 9999-r3  | 0    |       |        | o    |
+----------+------+-------+--------+------+

After stage 1:

========== ====== ======= ======== ======
 Version    Slot   amd64   ~amd64   \*\*
========== ====== ======= ======== ======
 2.10.2     0      o
 2.11.0     0              o
 9999-r3    0                       o
========== ====== ======= ======== ======

Example (dev-lang/python)
-------------------------
Imagine you have binary versions below:

=========== ========== ======= ======== ======
 Version     Slot       amd64   ~amd64   \*\*
=========== ========== ======= ======== ======
 2.7.10-r1   2.7        o
 2.7.12      2.7        o
 3.4.3-r1    3.4        o
 3.4.5       3.4/3.4m   o
 3.5.2       3.5/3.5m           o
=========== ========== ======= ======== ======

After stage 1:

=========== ========== ======= ======== ======
 Version     Slot       amd64   ~amd64   \*\*
=========== ========== ======= ======== ======
 2.7.12      2.7        o
 3.4.5       3.4/3.4m   o
 3.5.2       3.5/3.5m           o
=========== ========== ======= ======== ======

Stage 2
=======
Scan every binary package from stage 1, filtering out binary packages in 2 cases:

1. ebuild file in binary package and portage tree differs (ignoring KEYWORDS change)
2. has USE flags as same as a binary package scanned before (same PF, e.g. uwsgi-2.0.13-r1)

******************
Why not eclean-pkg
******************
For one package, I mean, a category/package tuple,
eclean-pkg preserves all binary packages that its corresponding ebuild exists in portage tree,
**regardless** of whether whose ebuild file has been updated in portage tree.

eclean-pkg has poor support for FEATURE=binpkg-multi-instance.
Though ``binpkg-multi-instance`` makes it possible to save multiple binary packages
with different USE flags for one version, which with *same* USE flags should be cleaned out.
eclean-pkg doesn't.

with -d eclean-pkg can work aggressive. It cleans out all binary packages except
those matching the *installed* version *exactly*\ .
(exactly means only one tbz2 or xpak for the installed version left afterwards).

For me, lower version binary packages in same slot and keyword are much less reused.
And with -d, it's much far away from my needs since I may install a package just removed yesterday
and I serves multiple binary packages of one version with different USE for multiple machines.
(e.g. USE="X" and USE="-X")

*****
Usage
*****

Quick Tutorial
==============
Run ``./eix-pkgcleaner.sh``

More
====

Running in non-interactive mode
-------------------------------
``./eix-pkgcleaner.sh | less``

In this mode, output all files to remove with full paths.

Arguments
---------
- -u: Run eix-update first

Environment Variables
---------------------
``DEBUG=1 SCAN_SLOT=0 SCAN_KEYWORD=0 ./eix-pkgcleaner.sh``

DEBUG
^^^^^
Accept values: 0-4

Default value: 0

Description: Try it and you will know.

SCAN_SLOT
^^^^^^^^^
Accept values: 0, 1

Default value: 1

Description: If set to 0, all versions are regarded to be in slot 0.
Taking dev-lang/python above as example, after cleanup, only 3.4.5 and 3.5.2 preserved.

SCAN_KEYWORD
^^^^^^^^^^^^
Accept values: 0, 1

Default value: 1

Description: If set to 0, all versions are regarded to have keyword ARCH (stable).
Taking dev-vcs/git above as example, after cleanup, only 9999-r3 preserved.
It's somehow the same as setting ACCEPT_KEYWORDS="**".

********
Untested
********
1. Overlay

.. rubric:: Footnotes
.. [#keyword] Keywords in ebuild. Will not be influenced by per-package accept_keywords but global ACCEPT_KEYWORDS.
