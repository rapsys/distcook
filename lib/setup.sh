#! /bin/sh -e

#Remove cache
if [ -f "$PWD/root/var/cache/urpmi/mirrors.cache" ]; then
	rm -f "$PWD/root/var/cache/urpmi/mirrors.cache"
fi
if [ -f "$PWD/root/var/cache/urpmi/.metalink" ]; then
	rm -f "$PWD/root/var/cache/urpmi/.metalink"
fi

#Bind mount
#XXX: umount many time just in case
umount "$PWD/root/proc" "$PWD/root/sys" || true
mount --bind /proc "$PWD/root/proc"
mount --bind /sys "$PWD/root/sys"

#Setup clock
cat << EOF > "$PWD/root/etc/sysconfig/clock"
ZONE=$ZONE
ARC=false
UTC=true
EOF

#Fix timezone for urpmi
if [ -f "$PWD/root/usr/share/zoneinfo/$ZONE" ]; then
	ln -fs "../usr/share/zoneinfo/$ZONE" "$PWD/root/etc/localtime"
fi

#Add urpmi ressources
LC_ALL=C chroot "$PWD/root" urpmi.removemedia -a
#--all-media
LC_ALL=C chroot "$PWD/root" urpmi.addmedia --distrib --mirrorlist http://mirrors.mageia.org/api/mageia.$MGARELEASE.$ARCH.list

umount "$PWD/root/proc" "$PWD/root/sys"

#perl -pne 's%(.*testing.*) {\n%\1 {\n  ignore\n%i' -i "$PWD/root/etc/urpmi/urpmi.cfg"
#perl -pne 'undef $/; s% +{(?:\n +.(?:country|proximity|longitude|arch|version|zone|latitude).[^,]+,){7}\n +.url.[^,]+distrib-coffee[^,]+,(?:\n +.(?:type|proximity_corrected).[^,]+,){2}\n%%' -i "$PWD/root/var/cache/urpmi/mirrors.cache"

