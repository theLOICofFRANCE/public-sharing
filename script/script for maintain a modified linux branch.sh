#!/bin/bash
# Script for maintain a modified linux branch.
# Version 0.0.1
# Under licence GPL v2, developed by HacKurx.

# Make sure you work in the linux tree
if [ ! -f REPORTING-BUGS ]; then
    echo "Use this script in linux directory !"
	exit 0
fi

# Start incrementally loop (53 to 108 +1)
kversion=53
while [ $kversion -ne 109 ] ; do

    # Download specific linux changelog
    wget -P /tmp -c https://cdn.kernel.org/pub/linux/kernel/v3.x/ChangeLog-3.10.$kversion

    # Sort the patchs by commit date for wget and after
    grep "^commit " /tmp/ChangeLog-3.10.$kversion | tac | sed -e 's#commit #https://github.com/torvalds/linux/commit/#g' | sed 's#$#.patch#' > /tmp/wget.txt

    # Download the commits in patch format
    while read line; do wget -P /tmp -c $line ; done < /tmp/wget.txt

    # Create a simple list of patches
    cut -d/ -f7 /tmp/wget.txt > /tmp/all-patch.txt

    # Prepare files to put the patches on each side
    mkdir /tmp/patch-ok
    mkdir /tmp/patch-nok

    # Apply the patches whose dry-run went well
    for i in $(cat /tmp/all-patch.txt); do 
        if patch -Np1 -s --dry-run < /tmp/$i; then
            patch -Np1 --no-backup-if-mismatch < /tmp/$i
		    mv /tmp/$i /tmp/patch-ok/
        fi
    done

# Stop incrementally loop
kversion=$(($kversion + 1))
done

# Inform and move failures
clear
echo "Patch not applied:"
mv `ls -1 /tmp/*.patch` /tmp/patch-nok/
echo `ls -1 /tmp/patch-nok/*.patch`

# Bye
exit 0
