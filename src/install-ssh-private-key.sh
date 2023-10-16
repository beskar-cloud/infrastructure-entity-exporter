#!/usr/bin/env bash
# Install ssh private key
# install-ssh-private-key.sh <private-key-or-file-with-private-key>

set -eo pipefail

PRIVATE_KEY="$1"

if [ ! -d "${HOME}/.ssh" ]; then
  rm -f "${HOME}/.ssh"
  mkdir "${HOME}/.ssh"
fi
if [ -r "${PRIVATE_KEY}" -a -s "${PRIVATE_KEY}" ]; then
    cat "${PRIVATE_KEY}"
else
    echo "${PRIVATE_KEY}"
fi > ${HOME}/.ssh/id_rsa
chmod 700 ${HOME}/.ssh
chmod 600 ${HOME}/.ssh/id_rsa
ls -la ${HOME}/.ssh/id_rsa
