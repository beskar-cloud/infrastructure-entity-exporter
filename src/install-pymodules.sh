#!/usr/bin/env bash
# 
# install-pymodules.sh <pip-requirement-file> [module-name] ...
# 
# installs python modules from various sources
# * <pip-requirement-file> i.e. modules listed in text file
# * [module-name]          i.e. explicitly named modules

set -eo pipefail

YUM='yum -y'
PIP='python3 -m pip'

function install_mods_from_requirement_file() {
    local file="$1"
    ${PIP} --version &>/dev/null || ${YUM} install python3-pip
    ${PIP} install --upgrade pip
    if  [ "$(grep -v '^#' "${file}" | wc -w)" -gt "0" ]; then
        ${PIP} install --requirement "${file}"
    fi
}

function install_mods() {
    ${PIP} install "$@"
}

for i_arg in "$@"; do
  if [ -r "${i_arg}" ]; then
      install_mods_from_requirement_file "${i_arg}"
  else
      install_mods "${i_arg}"
  fi
done

