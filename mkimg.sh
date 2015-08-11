#!/bin/sh

# Build disk image and populate boot data
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

if [ -n "${com0sp+1}" ]; then
  COM0="com0-${com0sp}-"
else
  COM0=''
fi
IMAGE=resflash-${MACHINE}-${COM0}${DATE}.img
echo "Creating disk image: ${IMAGE}..."

# Build the image shell

dd if=/dev/zero of=${IMAGE} bs=1m count=1 seek=$((${imgsizeinmb} - 1)) \
status=none

# Fdisk the image

get_next_vnd
imgvnd=${nextvnd}
vnconfig ${imgvnd} ${IMAGE}
# CHS is bogus, we're not going to deal with it and require an LBA-aware BIOS
fdisk -iy -f ${basedir}/usr/mdec/mbr ${imgvnd} >> ${BUILDPATH}/00.mkimg.fdisk \
2>&1
fdisk ${imgvnd} >> ${BUILDPATH}/00.mkimg.fdisk 2>&1

# Build the disklabel: 16 MiB /mbr, two / + 2 MiB headroom, 100 MiB /cfg

${ESCECHO} "\
a a\n$((4 * 1024 * 1024 / ${BYTESECT}))\n$((16 * 1024 * 1024 / ${BYTESECT}))\n\n\
a d\n\n$((${rootsizeinb} / ${BYTESECT}))\n\n\
a e\n\n$((${rootsizeinb} / ${BYTESECT}))\n\n\
a f\n\n\n\n\
q\n\n" | disklabel -E ${imgvnd} >> ${BUILDPATH}/01.mkimg.disklabel 2>&1
disklabel ${imgvnd} >> ${BUILDPATH}/01.mkimg.disklabel 2>&1

# Create /mbr and /cfg filesystems and mount

mkdir -p ${BUILDPATH}/mbr ${BUILDPATH}/cfg
newfs ${imgvnd}a >> ${BUILDPATH}/02.mkimg.newfs 2>&1
newfs ${imgvnd}f >> ${BUILDPATH}/02.mkimg.newfs 2>&1
mount -o async,noatime /dev/${imgvnd}a ${BUILDPATH}/mbr
mount -o async,noatime /dev/${imgvnd}f ${BUILDPATH}/cfg
mkdir -p ${BUILDPATH}/mbr/etc ${BUILDPATH}/cfg/etc ${BUILDPATH}/cfg/var

# Install biosboot(8), boot(8), and boot.conf

installboot -r ${BUILDPATH}/mbr ${imgvnd} ${basedir}/usr/mdec/biosboot \
${basedir}/usr/mdec/boot >> ${BUILDPATH}/03.mkimg.installboot 2>&1
echo 'set device hd0d' > ${BUILDPATH}/mbr/etc/boot.conf

# Set com0 console, if directed

if [ -n "${com0sp+1}" ]; then
  # Change speed first to skip extra 5s wait
  echo "stty com0 ${com0sp}" >> ${BUILDPATH}/mbr/etc/boot.conf
  echo 'set tty com0' >> ${BUILDPATH}/mbr/etc/boot.conf
fi

