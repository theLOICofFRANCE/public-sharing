#!/bin/bash
# Script for maintain a modified linux branch.
# Version 0.0.1
# Under licence GPL v2, developed by HacKurx.


# Make sure you work in the linux tree
if [ ! -f REPORTING-BUGS ]; then
    echo "Use this script in linux directory !"
	exit 0
fi

# Download specific linux changelog
wget -P /tmp -c https://cdn.kernel.org/pub/linux/kernel/v4.x/ChangeLog-4.9.112

# Sort the patchs by commit date for wget and after
grep "^commit " '/tmp/ChangeLog-4.9.112' | tac | sed -e 's#commit #https://github.com/torvalds/linux/commit/#g' | sed 's#$#.patch#' > /tmp/wget.txt

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

# Inform and move failures
clear
echo "Patch not applied:"
mv `ls -1 /tmp/*.patch` /tmp/patch-nok/
echo `ls -1 /tmp/patch-nok/*.patch`
