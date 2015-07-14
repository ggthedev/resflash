#!/bin/sh

# resflash master build script
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

set -o errexit
set -o nounset
if [ "$(set -o|grep pipefail)" ]; then
  set -o pipefail
fi

. ./resflash.sub
. ./build_resflash.sub

VERSION=5.7.0
BYTESECT=512

# Parse options first
while :; do
  if [ ${#} -eq 0 ]; then
    usage_and_exit
  fi

  case ${1} in
    -p) pkgdir=${2}; shift 2;;
    -s) com0sp=${2}; shift 2;;
    -*) usage_and_exit;;
    *) break;;
  esac
done

# Parse remaining args
case ${#} in
  2) imgsizeinmb=${1}
     basedir=${2};;
  *) usage_and_exit;;
esac

# Verify root user
if [ $(id -u) -ne 0 ]; then
  echo 'Must be run as root.'
  exit 1
fi

# Verify available vnds
if [ $(vnconfig -l|grep 'not in use'|wc -l) -lt 2 ]; then
  ${ESCECHO} "Not enough vnds are available:\n$(vnconfig -l)"
  exit 1
fi

${ESCECHO} "resflash ${VERSION}\n"

# Validate base unpacking
validate_base_dir ${basedir}

BUILDPATH=$(mktemp -t -d resflash.XXXXXX)
DATE=$(date +%Y%m%d_%H%M)

trap "umount_all; echo \*\*\* Error encountered, retaining logs. BUILDPATH: ${BUILDPATH} \*\*\*; exit 1" ERR INT

# Build disk image and populate boot data
. ./mkimg.sh

# Build and configure primary filesystem
. ./mkfs.sh

# Clean up
umount_all
rm -r ${BUILDPATH}

${ESCECHO} "Build complete!\n\nFile sizes:\n$(ls -lh resflash-*-${DATE}.{fs,img}|awk '{ print $5"\t"$9 }')\nDisk usage:\n$(du -h resflash-*-${DATE}.{fs,img})"

