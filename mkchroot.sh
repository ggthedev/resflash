#!/bin/sh

# Perform chroot activities on the mounted primary filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

# Set up a temporary /tmp

mount -t tmpfs -o noatime,nodev,nosuid,noexec tmpfs ${BUILDPATH}/fs/tmp

# Run fw_update, set up a temporary resolv.conf if necessary

echo 'Running fw_update...'
${ESCECHO} "nameserver 8.8.8.8\nlookup file bind" > ${BUILDPATH}/fs/etc/resolv.conf
if ! chroot ${BUILDPATH}/fs fw_update -a >> ${BUILDPATH}/05.mkchroot.fw_update 2>&1; then
  # Handle both arch and snapshot binary incompatibilities
  fw_update -a >> ${BUILDPATH}/05.mkchroot.fw_update 2>&1
  cp -fRPp /etc/firmware/* ${BUILDPATH}/fs/etc/firmware
  cp -fRPp /var/db/pkg/*-firmware-* ${BUILDPATH}/fs/var/db/pkg
fi
rm ${BUILDPATH}/fs/etc/resolv.conf

# Install packages, if directed

if [ -n "${pkgdir+1}" ]; then
  echo 'Installing packages...'
  mkdir -p ${BUILDPATH}/fs/tmp/pkg
  cp ${pkgdir}/*.tgz ${BUILDPATH}/fs/tmp/pkg
  if ! chroot ${BUILDPATH}/fs sh -c 'pkg_add -vi -D unsigned /tmp/pkg/*.tgz' >> ${BUILDPATH}/06.mkchroot.pkg_add 2>&1; then
    echo '*** WARNING: Package installation failed due to binary incompatibility, skipping. ***'
  fi
fi

# Clean up

umount ${BUILDPATH}/fs/tmp

