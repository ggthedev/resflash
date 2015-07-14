#!/bin/sh

# Update root password and save related files to /cfg
# Copyright Brian Conway <bconway@rcesoftware.com>, see LICENSE for details

set -o errexit
set -o nounset
if [ "$(set -o|grep pipefail)" ]; then
  set -o pipefail
fi

if passwd root; then
  echo 'Saving root password...'

  # /cfg may have been left mounted accidentally
  if [ -z "$(mount|grep /cfg)" ]; then
    mount /cfg
  fi
  trap 'sync; umount /cfg; exit 1' ERR INT

  for saver in master.passwd spwd.db; do
      tar cf - -C /etc ${saver} | tar xvpf - -C /cfg/etc
  done

  sync
  umount /cfg
fi

