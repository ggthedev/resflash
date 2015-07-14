#!/bin/sh

# Save SSH keys to /cfg
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

set -o errexit
set -o nounset
if [ "$(set -o|grep pipefail)" ]; then
  set -o pipefail
fi

echo 'Saving SSH keys...'

# /cfg may have been left mounted accidentally
if [ -z "$(mount|grep /cfg)" ]; then
  mount /cfg
fi
trap 'sync; umount /cfg; exit 1' ERR INT

# tar -C doesn't play nicely with glob(3)
cwd=$(pwd)
cd /etc
tar cf - ssh/ssh_host_*key* | tar xvpf - -C /cfg/etc
cd ${cwd}

sync
umount /cfg

