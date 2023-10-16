#!/bin/bash
# ostack-entity-normalize.sh <dump-dir> [files-glob]
#
# Align / Unify all received entity files:
# * sort keys of the objects
# * sort Glance Image Tags

SCRIPT_DIR="$(dirname $(readlink -f $0))"

DUMP_ROOTDIR="$1"
FILES_GLOB="${2:-"*.json"}"

set -eo pipefail

function file_dup_create() {
  local file="$1"
  cp -f "${file}" "${file}.tmp"
}

function file_dup_remove() {
  local file="$1"
  rm -f "${file}.tmp"
}

# main steps
FILES="$(find "${DUMP_ROOTDIR}" -type f -name "${FILES_GLOB}")"
IMAGE_FILES="$(find "${DUMP_ROOTDIR}" -type f -name "*-image.json")"

# sort object keys alphabetically
echo -n "Align all entity files: "
for i_file in ${FILES}; do
    file_dup_create "${i_file}"
    cat "${i_file}.tmp" | jq --sort-keys . > "${i_file}"
    echo -n $?
    file_dup_remove "${i_file}"
done
echo

# sort Glance image tags
echo -n "Align Glance image entity files (sort Tags): "
for i_file in ${IMAGE_FILES}; do
    file_dup_create "${i_file}"
    cat "${i_file}.tmp" | jq --sort-keys 'setpath(["tags"]; .tags | sort)' > "${i_file}"
    echo -n $?
    file_dup_remove "${i_file}"
done
echo

# remove volatile values from hypervisors
HYPERVISOR_FILES="$(find "${DUMP_ROOTDIR}" -type f -name "*-hypervisor.json")"
HYPERVISOR_FIELDS_REMOVE_REGEXP="(host_time|load_average|uptime|disk_available_least)"
echo -n "Remove volatile fields ${HYPERVISOR_FIELDS_REMOVE_REGEXP} from hypervisors: "
for i_file in ${HYPERVISOR_FILES}; do
    file_dup_create "${i_file}"
    grep -Ev "\"${HYPERVISOR_FIELDS_REMOVE_REGEXP}\":" "${i_file}.tmp" > "${i_file}"
    echo -n $?
    file_dup_remove "${i_file}"
done
echo
