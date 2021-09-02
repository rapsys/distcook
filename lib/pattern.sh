#! /bin/sh -e

#Fix bash completion
perl -pne 's%(?:(COMP_CONFIGURE_HINTS|COMP_TAR_INTERNAL_PATHS)=1?)%${1}=1%' -i "$PWD/root/etc/sysconfig/bash-completion"

#Disable gpg agent
perl -pne 's%(?:(START_GPGAGENT|START_GPGAGENT_SH)=(?:"?(no|yes)"?)?)%${1}="no"%' -i "$PWD/root/etc/sysconfig/gnupg2"

#Locale config
cat << EOF > "$PWD/root/etc/vconsole.conf"
KEYMAP=$KEYMAP
FONT=lat0-16
EOF
cat << EOF > "$PWD/root/etc/locale.conf"
LANGUAGE=$LOCALE:${LOCALE_ALT}
LANG=$LOCALE
EOF

#Setup networking
cat << EOF > "$PWD/root/etc/sysconfig/network"
NETWORKING=yes
AUTOMATIC_IFCFG=no
EOF

#Setup network
cat << EOF > "$PWD/root/etc/hostname"
${NETHOSTNAME}
EOF

#Setup machine-info
cat << EOF > "$PWD/root/etc/machine-info"
CHASSIS=server
EOF

#Setup hosts
#XXX: we remove mask from address
cat << EOF > "$PWD/root/etc/hosts"
127.0.0.1				localhost
::1					localhost
${NETADDRESS4%/*}				${NETHOSTNAME}	${NETALIAS}
${NETADDRESS6%/*}	${NETHOSTNAME}	${NETALIAS}
EOF

#Fix named config
perl -pne 's%listen-on port 53 \{ .+; \};%listen-on port 53 { 127.0.0.1; };%' -i "$PWD/root/etc/named.conf"
perl -pne 's%listen-on-v6 port 53 \{ .+; \};%listen-on-v6 port 53 { ::1; };%' -i "$PWD/root/etc/named.conf"

#Network
mkdir -p "$PWD/root/etc/systemd/network"
if [ ! -z "${NETCONFIG}" -a "${NETCONFIG}" = 'static' ]; then
	cat << EOF > "$PWD/root/etc/systemd/network/${NETMAC}.network"
[Match]
MACAddress=${NETMAC}

[Network]
DHCP=no
Address=${NETADDRESS4}
Address=${NETADDRESS6}
DNS=${NETDNS}

[Route]
Destination=${NETGATEWAY4}

[Route]
Destination=0.0.0.0/0
Gateway=${NETGATEWAY4}

[Route]
Destination=${NETGATEWAY6}

[Route]
Destination=::/0
Gateway=${NETGATEWAY6}
EOF
else
	cat << EOF > "$PWD/root/etc/systemd/network/${NETMAC}.network"
[Match]
MACAddress=${NETMAC}

[Network]
DHCP=yes
EOF
fi

#Mysql
mkdir -p "$PWD/root/var/lib/mysql"

#Mail
mkdir -p "$PWD/root/var/spool/mail"

#Fstab
cat << EOF > "$PWD/root/etc/fstab"
UUID=${BOOTUUID}	/boot		ext3	defaults,noatime 1 2
UUID=${DATAUUID}	/		btrfs	subvol=/slash,defaults,relatime 1 1
UUID=${SWAPAUUID}	none		swap	sw 0 0
UUID=${SWAPBUUID}	none		swap	sw 0 0
UUID=${DATAUUID}	/home		btrfs	subvol=/home,defaults,relatime 1 1
UUID=${DATAUUID}	/var/lib/mysql	btrfs	subvol=/mysql,defaults,relatime 1 1
UUID=${DATAUUID}	/var/spool/mail	btrfs	subvol=/mail,defaults,relatime 1 1
proc						/proc	proc	defaults 0 0
EOF

#Crypttab
#XXX: Don't forget to add option nofail,noauto for every devices requiring manual unlocking
cat << EOF > "$PWD/root/etc/crypttab"
${DATANAME}	UUID=${LUKSDATAUUID}
EOF

#Set resolv.conf
ln -fs "/run/systemd/resolve/resolv.conf" "$PWD/root/etc/resolv.conf"
#Disable LLMNR, enable localhost
perl -pne 's/^#LLMNR=yes$/LLMNR=no/;s/^#DNS=/DNS=127.0.0.1/' -i "$PWD/root/etc/systemd/resolved.conf"

#Disable resolvconf
rm -f "$PWD/root/etc/resolvconf/run/enable-updates"

#Mail
cat << EOF >> "$PWD/root/etc/mdadm.conf"
MAILADDR ${MAIL}
EOF

#Password
echo -n "$ROOTPASS" | chroot $PWD/root passwd root --stdin
chroot $PWD/root adduser -m "$USERLOGIN"
echo -n "$USERPASS" | chroot $PWD/root passwd "$USERLOGIN" --stdin

# Fix grub config
perl -pne 's/^GRUB_TIMEOUT=[0-9]+$/GRUB_TIMEOUT=1/' -i $PWD/root/etc/default/grub

#Shorewall
cat << EOF >> $PWD/root/etc/shorewall/zones
net		ipv4
EOF
cat << EOF >> $PWD/root/etc/shorewall/policy
fw	net	ACCEPT
net	all	DROP	info
all	all	REJECT	info
EOF
cat << EOF >> $PWD/root/etc/shorewall/rules
INCLUDE	rules.drakx
EOF
cat << EOF > $PWD/root/etc/shorewall/rules.drakx
ACCEPT	net	fw	udp	68,6700:7000	-
ACCEPT	net	fw	icmp	8	-
ACCEPT	net	fw	tcp	20,21,22,80,443,6700:7000	-
EOF

#Shorewall6
cat << EOF >> $PWD/root/etc/shorewall6/zones
net		ipv6
EOF
cat << EOF >> $PWD/root/etc/shorewall6/policy
fw	net	ACCEPT
net	all	DROP	info
all	all	REJECT	info
EOF
cat << EOF >> $PWD/root/etc/shorewall6/rules
INCLUDE	rules.drakx
EOF
cat << EOF > $PWD/root/etc/shorewall6/rules.drakx
ACCEPT	net	fw	udp	546,6700:7000	-
ACCEPT	net	fw	icmp	128	-
ACCEPT	net	fw	tcp	20,21,22,80,443,546,6700:7000	-
EOF

# Disable old services
# Strip WantedBy=multi-user.target in [Install] section of lm_sensors.service ?
for s in lm_sensors network network-auth network-up resolvconf smartd; do
	if [ -f "$PWD/root/etc/rc.d/init.d/$s" -a -x "$PWD/root/etc/rc.d/init.d/$s" ]; then
		chroot $PWD/root /usr/lib/systemd/systemd-sysv-install disable $s
	fi
	if [ -f "$PWD/root/etc/systemd/system/multi-user.target.wants/${s}.service" ]; then
		rm -f "$PWD/root/etc/systemd/system/multi-user.target.wants/${s}.service"
	fi
done

# Extract last kernel version
KVER=`chroot $PWD/root rpm -qa | perl -pne '/kernel-server-latest/||undef $_;s%^kernel-(server)-latest-([^-]+)-(.+)$%\2-\1-\3%'`
#XXX: we do not regenerate initrd here, it will be generated at image build step
rm -f "$PWD/root/boot/initrd-${KVER}.img"

# Check rc.local state
if [ -f "$PWD/root/etc/rc.d/rc.local" ]; then
	echo "$PWD/root/etc/rc.d/rc.local not empty"
	exit 1
fi

# First boot startup script
#XXX: regenerate initrd after first successfull boot to strip from useless modules
touch "$PWD/root/etc/rc.d/rc.local"
chmod a+x "$PWD/root/etc/rc.d/rc.local"
cat << EOF > "$PWD/root/etc/rc.d/rc.local"
#! /bin/sh
. /etc/init.d/functions
case "\$1" in
	start)
		gprintf "Disabling lm_sensors.service: "
		/usr/bin/systemctl disable lm_sensors.service
		[ \$? -eq 0 ] && success || failure
		echo
		gprintf "Stopping lm_sensors.service: "
		/usr/bin/systemctl stop lm_sensors.service
		[ \$? -eq 0 ] && success || failure
		echo
		gprintf "Generating initrd: "
		/usr/sbin/mkinitrd -f -v /boot/initrd-${KVER}.img ${KVER}
		[ \$? -eq 0 ] && success || failure
		echo
		rm -f "\$0"
		exit 0
		;;
	*)
		echo "Usage: \$0 start" >&2
		exit 3
		;;
esac
EOF

# Fix msec
chroot "$PWD/root" msec -f webserver

# Fix postfix
perl -pne "my \$m='${MAIL}'; s%^(root:[\\t\\s]+)postfix\$%\\1\$m%" -i "$PWD/root/etc/postfix/aliases"

# Generate ssh keys
chroot "$PWD/root" /usr/sbin/sshd-keygen

# Allow root access
#XXX: forced because msec decides otherwise
perl -pne 's%^PermitRootLogin .*%PermitRootLogin yes%' -i "$PWD/root/etc/ssh/sshd_config"

# Add rsa key if available
#XXX: dsa is unsupported anymore
if [ -e "$HOME/.ssh/id_rsa.pub" ]; then
	[ ! -d "$PWD/root/root/.ssh" ] && mkdir -m 0700 "$PWD/root/root/.ssh"
	cp -f "$HOME/.ssh/id_rsa.pub" "$PWD/root/root/.ssh/authorized_keys"
fi

#TODO ntp /etc/systemd/timesyncd.conf

# Force enable systemd-networkd.service
chroot "$PWD/root" /usr/bin/systemctl enable systemd-networkd.service

# Force enable systemd-resolved.service
chroot "$PWD/root" /usr/bin/systemctl enable systemd-resolved.service

# Cleanup tmp and run
rm -fr $PWD/root/tmp/* $PWD/root/run/*
