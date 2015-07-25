#!/bin/sh

# Build and configure primary filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

FS=resflash-${MACHINE}-${COM0}${DATE}.fs
echo "Creating filesystem image: ${FS}..."

# Build the fs shell

dd if=/dev/zero of=${FS} bs=1 count=1 seek=$((${fssizeinb} - 1)) status=none

# Newfs the image

get_next_vnd
fsvnd=${nextvnd}
vnconfig ${fsvnd} ${FS}
newfs ${fsvnd}c >> ${BUILDPATH}/04.mkfs.newfs 2>&1

# Mount and populate filesystem

echo 'Populating filesystem and configuring fstab...'
mkdir -p ${BUILDPATH}/fs
mount -o async,noatime /dev/${fsvnd}c ${BUILDPATH}/fs
tar cf - -C ${basedir} . | tar xpf - -C ${BUILDPATH}/fs
mkdir -p ${BUILDPATH}/fs/cfg ${BUILDPATH}/fs/mbr

# Add resflash hooks

mkdir -p ${BUILDPATH}/fs/resflash
cp -p host/* ${BUILDPATH}/fs/resflash
chown -R root:wheel ${BUILDPATH}/fs/resflash
echo ${VERSION} > ${BUILDPATH}/fs/resflash/.version
cp etc/resflash.conf ${BUILDPATH}/fs/etc
chown root:wheel ${BUILDPATH}/fs/etc/resflash.conf
echo '/resflash/resflash.save' >> ${BUILDPATH}/fs/etc/rc.shutdown

sed -e '/rm.*fastboot/a\
/resflash/rc.resflash\
# Re-read rc.conf and rc.conf.local from the new /etc\
_rc_parse_conf\
' ${BUILDPATH}/fs/etc/rc > ${BUILDPATH}/rc.new
cp ${BUILDPATH}/rc.new ${BUILDPATH}/fs/etc/rc

# Populate /dev

cwd=$(pwd)
cd ${BUILDPATH}/fs/dev
./MAKEDEV all
cd ${cwd}

# Configure fstab

duid=$(disklabel ${imgvnd}|grep duid|awk '{ print $2 }')
echo "${duid}.a /mbr ffs rw,noatime,nodev,nosuid,noexec,noauto 1 2" > ${BUILDPATH}/fs/etc/fstab
echo "${duid}.d / ffs ro,noatime,nodev 1 1" >> ${BUILDPATH}/fs/etc/fstab
echo "${duid}.f /cfg ffs rw,noatime,nodev,nosuid,noexec,noauto 1 2" >> ${BUILDPATH}/fs/etc/fstab
echo 'tmpfs /tmp tmpfs rw,noatime,nodev,nosuid,noexec,-s64M 0 0' >> ${BUILDPATH}/fs/etc/fstab

# Install random.seed and host.random

dd if=/dev/random of=${BUILDPATH}/fs/etc/random.seed bs=512 count=1 status=none
chmod 600 ${BUILDPATH}/fs/etc/random.seed
dd if=/dev/random of=${BUILDPATH}/fs/var/db/host.random bs=65536 count=1 status=none
chmod 600 ${BUILDPATH}/fs/var/db/host.random

# Set com0 ttys, if directed

if [ -n "${com0sp+1}" ]; then
  sed -e '/^ttyC/s/on.*secure/off\ secure/' \
      -e "/^tty00/s/std\.9600/std\.${com0sp}/" \
      -e '/^tty00/s/unknown.*/vt220\ on\ secure/' ${BUILDPATH}/fs/etc/ttys > ${BUILDPATH}/ttys.new
  cp ${BUILDPATH}/ttys.new ${BUILDPATH}/fs/etc/ttys
fi

# Perform chroot activities (fw_update, packages)

. ./mkchroot.sh

# Unmount, and free filesystem for copy

sync
umount ${BUILDPATH}/fs
vnconfig -u ${fsvnd}

# Write filesystem to image's d partition and calculate checksum

echo 'Writing filesystem to image and calculating checksum...'
(dd if=${FS} bs=1m status=none|tee /dev/fd/3|dd of=/dev/r${imgvnd}d bs=16k >> ${BUILDPATH}/07.mkfs.dd 2>&1;) 3>&1|${ALG} > ${FS}.${ALG}

