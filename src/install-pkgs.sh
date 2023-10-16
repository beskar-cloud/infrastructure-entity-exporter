#!/usr/bin/env bash
# 
# install-pkgs.sh <pkg-requirement-file> ... [pkg-repository-url] ...  [package-name] ...
# 
# installs linux packages from various sources
# * <pkg-requirement-file> i.e. packages listed in text file
# * [pkg-repository-url]   i.e. enable foreign package repository
# * [package-name]         i.e. explicitly listed packages
#
# Note: Only RHEL-like Linux distros with yum are supported at the moment

set -eo pipefail

YUM='yum -y'

function install_pkgs_from_requirement_file() {
    local file="$1"
    if  [ "$(grep -v '^#' "${file}" | wc -w)" -gt "0" ]; then
        if grep -q epel-release "${file}"; then
            ${YUM} install epel-release
        fi
    fi
    ${YUM} install $(grep -v '^#' "${file}")
}

function install_pkg_repository() {
    local repo_url="$1"
    ${YUM} install yum-utils
    yum-config-manager --add-repo "${repo_url}"
}

function install_pkgs() {
    ${YUM} install "$@"
}

for i_arg in "$@"; do
  if [ -r "${i_arg}" ]; then
      install_pkgs_from_requirement_file "${i_arg}"
  elif [[ "${i_arg}" =~ https?://.+ ]]; then
      install_pkg_repository "${i_arg}"
  else
      install_pkgs "${i_arg}"
  fi
done

