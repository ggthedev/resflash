#!/bin/sh

# Unmount a mounted resflash image or filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

set -o errexit
set -o nounset
if [ "$(set -o|grep pipefail)" ]; then
  set -o pipefail
fi

. ./resflash.sub

umount_all

rm -r /tmp/resflash.??????

