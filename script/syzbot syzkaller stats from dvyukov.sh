rm -f /tmp/base
BASE_HASHES=`git log --format="%H" v4.17..master`
for HASH in $BASE_HASHES; do
	git show --format="%B" "$HASH" | egrep "Reported-.*(syzbot|syzkaller)" >/dev/null
	if [ "$?" -eq 0 ]; then
		echo "base $HASH"
		echo `git log --format="%s" -n 1 $HASH` >> /tmp/base
	fi
done

rm -f /tmp/stable
STABLE_HASHES=`git log --format="%H" v4.17..v4.17.9`
for HASH in $STABLE_HASHES; do
	git show --format="%B" "$HASH" | egrep "Reported-.*(syzbot|syzkaller)" >/dev/null
	if [ "$?" -eq 0 ]; then
		echo "stable $HASH"
		echo `git log --format="%s" -n 1 $HASH` >> /tmp/stable
	fi
done

echo "present in both" `grep -Fxf /tmp/base /tmp/stable | wc -l`
echo "present in only in base" `grep -Fvxf /tmp/stable /tmp/base | wc -l`
echo "present in only in stable" `grep -Fvxf /tmp/base /tmp/stable | wc -l`