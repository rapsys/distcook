#! /bin/sh -e

# Failsafe check
if [ -z "$PWD" -o "$PWD" = "/" ]; then
	echo "Don't run it from slash moron"
	exit 1;
fi

# Check for trashed %_tmppath by ~/.rpmmacros or else
if [ "$(rpm --eval '%_tmppath')" != "/var/tmp" ]; then
	echo "Run with a clean %_tmppath rpm macro moron (start me from sudo su -)"
	exit 1;
fi

# Check if we have a root directory
if [ -d "$PWD/root" ]; then
	read -p 'Confirm root directory destruction (yes/NO): ' confirm
	if [ "$confirm" = "yes" -o "$confirm" = "YES" ]; then
		rm -fr "$PWD/root"
	elif [ ! "$confirm" = "no" -a ! "$confirm" = "NO" ]; then
		echo "I need a clean directory"
		exit 1;
	else
		read -p "I re-install over existing directory, press a key to continue"
	fi
fi

# Make root directory
mkdir -p "$PWD/root"

# Install base config
LC_ALL=C urpmi --downloader=wget --no-verify-rpm --no-recommends --noclean --auto --root=$PWD/root filesystem basesystem-minimal rpm urpmi grub kernel-server-latest vim-enhanced wget

# Reinstall lockdev to fix missing lock group on binary
LC_ALL=C urpmi --downloader=wget --no-verify-rpm --no-recommends --noclean --auto --replacepkgs --replacefiles --root=$PWD/root lockdev

# Install remaining
LC_ALL=C urpmi --downloader=wget --no-verify-rpm --no-recommends --noclean --auto --root=$PWD/root \
	acl \
	acpi \
	acpid \
	bash-completion \
	bc \
	bind \
	bind-utils \
	binutils \
	btrfs-progs \
	cronie-anacron \
	cryptmount \
	cryptsetup \
	deltarpm \
	dhcp-client \
	dosfstools \
	gdb \
	gdisk \
	git \
	git-prompt \
	git-svn \
	gnupg \
	gnupg2 \
	groff \
	hddtemp \
	hdparm \
	info \
	kernel-firmware \
	kernel-firmware-nonfree \
	lftp \
	lm_sensors \
	locales \
	locales-en \
	lshw \
	lsof \
	luit \
	lynx \
	mageia-gfxboot-theme \
	man \
	man-pages \
	mdadm \
	microcode \
	mirrordir \
	mlocate \
	msec \
	nail \
	ntfs-3g \
	openssh-server \
	openvpn \
	p7zip \
	parted \
	patch \
	pax \
	pciutils \
	postfix \
	rsnapshot \
	rsync \
	screen \
	sectool \
	shorewall \
	shorewall-ipv6 \
	smartmontools \
	strace \
	sudo \
	traceroute \
	tree \
	unzip \
	whois \
	xauth \
	xfsprogs \
	zip

# Install locale
if [ ! -z "$LOCALE_ALT" -a "$LOCALE_ALT" != 'en' ]; then
	LC_ALL=C urpmi --downloader=wget --no-verify-rpm --no-recommends --noclean --auto --root=$PWD/root \
		locales-${LOCALE_ALT} \
		man-pages-${LOCALE_ALT}
fi

# Install ihttpd
if [ ! -z "${IHTTPD_RPM}" -a -f "${IHTTPD_RPM}" ]; then
	LC_ALL=C urpmi --no-verify-rpm --no-recommends --noclean --auto --root=$PWD/root ${IHTTPD_RPM}
fi
