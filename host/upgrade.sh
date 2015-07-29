#!/bin/sh

# Upgrade the inactive root partition with a new filesystem and activate it
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

set -o errexit
set -o nounset
if [ "$(set -o|grep pipefail)" ]; then
  set -o pipefail
fi

# Parse out disks and partitions

duid=$(grep ' / ' /etc/fstab|awk '{ print $1 }'|awk -F . '{ print $1 }')
currpart=$(grep ' / ' /etc/fstab|awk '{ print $1 }'|awk -F . '{ print $2 }')
if [ ${currpart} == 'd' ]; then
  newpart=e
else
  newpart=d
fi
diskpart=$(mount|grep ' on / '|awk '{ print $1 }'|awk -F / '{ print $3 }')
currdisk=${diskpart%?}

case $(machine) in
  amd64) ALG=sha512;;
  i386) ALG=md5;;
  *) ALG=sha256;;
esac

MNTPATH=$(mktemp -t -d resflash.XXXXXX)

# Write filesystem to the inactive partition

echo 'Writing filesystem to inactive partition...'
(tee /dev/fd/3|dd of=/dev/${currdisk}${newpart} bs=16k >> \
${MNTPATH}/00.upgrade.dd 2>&1;) 3>&1|${ALG}

# Verify the newly written partition

echo 'Checking filesystem...'
fsck -fp /dev/${currdisk}${newpart}

# Update fstab for the current duid and new partition

mkdir -p ${MNTPATH}/fs
mount -o noatime /dev/${currdisk}${newpart} ${MNTPATH}/fs
# /cfg may have been left mounted accidentally
if [ -z "$(mount|grep /mbr)" ]; then
  mount /mbr
fi
trap 'sync; umount ${MNTPATH}/fs; umount /mbr; exit 1' ERR INT

echo 'Updating fstab...'
fsduid=$(grep ' / ' ${MNTPATH}/fs/etc/fstab|awk '{ print $1 }'|awk -F . \
'{ print $1 }')
sed -e "s/${fsduid}/${duid}/" \
    -e "/^${duid}.d/s/${duid}.d/${duid}.${newpart}/" \
    ${MNTPATH}/fs/etc/fstab > ${MNTPATH}/fstab.new
cp ${MNTPATH}/fstab.new ${MNTPATH}/fs/etc/fstab

# Update MBR, biosboot(8), and boot(8)

echo 'Updating MBR, biosboot(8), and boot(8)...'
fdisk -uy -f ${MNTPATH}/fs/usr/mdec/mbr ${currdisk} >> \
${MNTPATH}/01.upgrade.fdisk 2>&1
installboot -r /mbr ${duid} ${MNTPATH}/fs/usr/mdec/biosboot \
${MNTPATH}/fs/usr/mdec/boot >> ${MNTPATH}/02.upgrade.installboot 2>&1

sync
umount ${MNTPATH}/fs

# Set the new partition active

echo 'Everything looks good, setting the new partition active...'
sed -e "/^set device hd0/s/hd0[a-p]/hd0${newpart}/" \
    /mbr/etc/boot.conf > ${MNTPATH}/boot.conf.new
cp ${MNTPATH}/boot.conf.new /mbr/etc/boot.conf

sync
umount /mbr

rm -r ${MNTPATH}

echo 'Upgrade complete!'

