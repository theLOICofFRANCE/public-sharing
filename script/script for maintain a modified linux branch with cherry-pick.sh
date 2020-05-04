#!/bin/bash
# Script for maintain a modified linux branch.
# Version 0.0.1
# Under licence GPL v2, developed by HacKurx.

# Make sure you work in the linux tree
if [ ! -f MAINTAINERS ]; then
    echo "Use this script in linux directory !"
	exit 0
fi

kversion=120
kcommit=$(git log --oneline HEAD^..HEAD | awk '{print $1}')

# Download specific linux changelog
wget -P /tmp -c https://cdn.kernel.org/pub/linux/kernel/v4.x/ChangeLog-4.19.$kversion

# Sort the patchs by commit date for wget and after
grep "^commit " /tmp/ChangeLog-4.19.$kversion | tac | sed -e 's#commit ##g' > /tmp/get.txt

# Create a simple list of patches
cut -d/ -f7 /tmp/get.txt > /tmp/all-patch.txt

# obtain commits from the upstream branch
git remote add stable-4.19.y -t linux-4.19.y git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
git remote update stable-4.19.y

# Apply the patches whose dry-run went well
for i in $(cat /tmp/all-patch.txt); do 
    git cherry-pick -x $i
    git reset --hard && git clean -d -x -f
done

# See what has just been done
git log --oneline $kcommit...HEAD

# Bye
exit 0
