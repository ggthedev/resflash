#!/bin/sh

# Mount a resflash image or filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

set -o errexit
set -o nounset
if [ "$(set -o|grep pipefail)" ]; then
  set -o pipefail
fi

. ./resflash.sub

if [ ${#} -ne 1 ]; then
  echo "Usage: ${0} <resflash img or fs>"
  exit 1
fi

mount_img_or_fs ${1}

