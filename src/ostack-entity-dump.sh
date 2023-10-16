#!/bin/bash
# ostack-entity-dump.sh [--help|-h]
# ostack-entity-dump.sh <dump-dir> [entity] ...
#   dumps openstack entities (possibly specified as [entity] arguments to directory <dump-dir>
#
# Directory structure:
# <dump-dir>/domains
# <dump-dir>/domains/<domain-id>/users
# <dump-dir>/domains/<domain-id>/projects
# <dump-dir>/domains/<domain-id>/quotas
# <dump-dir>/domains/<domain-id>/projects/<project-id>/servers/
# <dump-dir>/domains/<domain-id>/projects/<project-id>/loadbalancers/
# <dump-dir>/domains/<domain-id>/projects/<project-id>/floating-ips
# <dump-dir>/domains/<domain-id>/projects/<project-id>/networks
# <dump-dir>/domains/<domain-id>/projects/<project-id>/subnets
# <dump-dir>/domains/<domain-id>/projects/<project-id>/routers
# <dump-dir>/...
#
# Notes:
# * if you want to export servers/loadbalancers/floating ips/networks/subnets/routers, you also need projects and domains, see the directory structure above
#
# Usage:
#   * dump (all exportable) ostack entities into directory ./openstack-dump-dir
#     source ./ostack-admin-rc.sh.inc
#     ./ostack-entity-dump.sh ./openstack-dump-dir
#   * dump ostack volume entities into directory ./openstack-volumes-dump-dir
#     source ./ostack-admin-rc.sh.inc
#     ./ostack-entity-dump.sh ./openstack-volumes-dump-dir volume

SCRIPT_DIR="$(dirname $(readlink -f $0))"
DUMP_ROOTDIR="$1"
shift
OBJECTS="$@"
[ -z "${OBJECTS}" ] && OBJECTS="domain user project image flavor server mapping quota volume service region hypervisor loadbalancer floating-ip subnet network router"

set -eo pipefail

if [ -z "${DUMP_ROOTDIR}" -o "${DUMP_ROOTDIR:0:1}" == "-" ]; then
  cat $0 | awk '$0~/^#[^!]/{print} NF==0{exit(0)}'
  [[ "${DUMP_ROOTDIR}" =~ ^-h|--help ]] && exit 0 || exit 1
fi

# constants
# ---------------------------------------------------------------------------
STEP_NAME="initialization (constants)"
JSON_SPLIT_TOOL="${SCRIPT_DIR}/json-split.awk"
STREAM_PRINTF_TOOL="${SCRIPT_DIR}/stream-printf.awk"

declare -A OBJECT_FILE_FMT
OBJECT_FILE_FMT[domain]="domains/%s-domain.json"
OBJECT_FILE_FMT[user]="domains/%s/users/%s-user.json"
OBJECT_FILE_FMT[project]="domains/%s/projects/%s-project.json"
OBJECT_FILE_FMT[quota]="domains/%s/quotas/%s-quota.json"
OBJECT_FILE_FMT[server]="domains/%s/projects/%s/servers/%s-server.json"
OBJECT_FILE_FMT[flavor]="flavors/%s-flavor.json"
OBJECT_FILE_FMT[image]="images/%s-image.json"
OBJECT_FILE_FMT[mapping]="mappings/%s-mapping.json"
OBJECT_FILE_FMT[volume]="volumes/%s-volume.json"
OBJECT_FILE_FMT[service]="services/%s-service.json"
OBJECT_FILE_FMT[region]="regions/%s-region.json"
OBJECT_FILE_FMT[hypervisor]="hypervisors/%s-hypervisor.json"
OBJECT_FILE_FMT[loadbalancer]="domains/%s/projects/%s/loadbalancers/%s-loadbalancer.json"
OBJECT_FILE_FMT[network]="domains/%s/projects/%s/networks/%s-network.json"
OBJECT_FILE_FMT[subnet]="domains/%s/projects/%s/subnets/%s-subnet.json"
OBJECT_FILE_FMT[floating-ip]="domains/%s/projects/%s/floating-ips/%s-floating-ip.json"
OBJECT_FILE_FMT[router]="domains/%s/projects/%s/routers/%s-router.json"

# lazy load ostack project to domain mapping
declare -A OSTACK_PRJ_TO_DOMAIN

# local functions
# ---------------------------------------------------------------------------
STEP_NAME="initialization (functions)"

function at_exit() {
  if [ -n "${DUMP_ROOTDIR}" -a -d "${DUMP_ROOTDIR}/__raw" ]; then
    set | grep "^OSTACK_PRJ_TO_DOMAIN" > "${DUMP_ROOTDIR}/__raw/OSTACK_PRJ_TO_DOMAIN.vardump"
  fi
  
  if [ "${STEP_NAME,,}" == "success" ]; then
	exit 0
  else
	echo "ERROR: $(basename $0) failed and aborted during the step \"${STEP_NAME}\"."
	exit 1
  fi
}
trap at_exit EXIT

function secs_to_HMS() {
    local seconds_count="${1:-0}"
    if [ "${seconds_count}" -ge $((60*60)) ]; then
        echo -n "$((${seconds_count}/3600))h$((${seconds_count}%3600/60))m$((${seconds_count}%60))s"
    elif [ "${seconds_count}" -ge 60 ]; then
        echo -n "$((${seconds_count}%3600/60))m$((${seconds_count}%60))s"
    else
        echo -n "$((${seconds_count}%60))s"
    fi
}

function log() {
    echo -e "[$(date +'%Y-%m-%dT%H:%M:%S')] $@ (running $(secs_to_HMS ${SECONDS}))" 1>&2
}

# ostack_cli_ro [openstack-client-args]
#   openstack client read-only wrapper
function ostack_cli_ro() {
    local object_type="$1"
    local object_action="$2"

    if [ -n "${object_type}" -a -n "${object_action}" ]; then
        if [[ -n "${object_type}" && "${object_action}" =~ ^(show|list)$ ]]; then
            openstack $* -f json
        else
            return 1
        fi
    else
        cat | awk '{if ($0 ~ /.+ (show|list)/){print $0 " -f json"}}' | \
          openstack
    fi
}

function dirs_exist() {
    local file_names="$1"
    for i_dir in $(echo "${file_names}" | xargs dirname | sort -u); do
        test -d "${i_dir}" || mkdir -p "${i_dir}"
    done
}

function concat_json_split() {
    local all_file="$1"
    local output_file_fmt="$2"
    local fields="$3"
    local all_items="$(cat "${all_file}" | jq .)"
    local file_names="$(echo "${all_items}" | jq -r "${fields}" | gawk -v "fmt=${output_file_fmt}\n" -f "${STREAM_PRINTF_TOOL}")"

    dirs_exist "${file_names}"

    echo "${all_items}" | gawk -v file_names_file=<(echo "${file_names}") -f "${JSON_SPLIT_TOOL}"
}

function concat_json_split_on_file_names() {
    local all_file="$1"
    local file_names="$2"

    dirs_exist "${file_names}"

    cat "${all_file}" | jq . | gawk -v file_names_file=<(echo "${file_names}") -f "${JSON_SPLIT_TOOL}"
}


function concat_json_split_detect_domain() {
    local all_file="$1"
    local output_file_fmt="$2"
    local fields="$3"
    local all_items="$(cat "${all_file}" | jq .)"

    local file_fmt_fields="$(echo "${all_items}" | jq -r "${fields}" | \
        while read i_field_line; do
            i_prj_id=$(echo "${i_field_line}" | awk '{printf $1}')
            i_object_id=$(echo "${i_field_line}" | awk '{printf $2}')
            i_domain_id="${OSTACK_PRJ_TO_DOMAIN[${i_prj_id,,}]}"
            if [[ "$i_object_id" ]]; then
                echo "${i_domain_id:-"unknown-orphaned"} ${i_prj_id} ${i_object_id}";
            else
                echo "${i_domain_id:-"unknown-orphaned"} unknown-orphaned ${i_prj_id}"; # i_object_id always exists, it was uncorrectly assigned to i_prj_id
            fi
        done)"
    local file_names="$(echo "${file_fmt_fields}" | gawk -v "fmt=${output_file_fmt}\n" -f "${STREAM_PRINTF_TOOL}")"

    dirs_exist "${file_names}"

    echo "${all_items}" | gawk -v file_names_file=<(echo "${file_names}") -f "${JSON_SPLIT_TOOL}"
}


function ostack_dump_xyz() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    local object_type="${3//-/ }"
    local object_type_single_word="$3"
    local jq_query_ids="$4"
    local ostack_brief_query_args="$5"
    local exit_callback_function="$6"
    local split_function="${7:-"concat_json_split"}"
    local brief_list_jq_id_query="${8:-".[].ID"}"

    ostack_cli_ro "${object_type}" list ${ostack_brief_query_args} > "${raw_entities_dir}/${object_type_single_word}s.brief.json"
    
    local entity_count="$(cat "${raw_entities_dir}/${object_type_single_word}s.brief.json" | jq '. | length')"
    log "INFO: ${entity_count} ${object_type} entities found (brief list)"
    [ "${entity_count}" == "0" ] && \
      return 0
    
    cat "${raw_entities_dir}/${object_type_single_word}s.brief.json" | jq -r "${brief_list_jq_id_query}" | \
      awk -v "object_type=${object_type}" '{print object_type " show " $1}' | \
      ostack_cli_ro > "${raw_entities_dir}/${object_type_single_word}s.detailed.json"
    local entity_count_detailed="$(cat "${raw_entities_dir}/${object_type_single_word}s.detailed.json" | jq -c '.' | wc -l)"
    log "INFO: ${entity_count_detailed} ${object_type} entities found (detailed list)"

    "${split_function}" "${raw_entities_dir}/${object_type_single_word}s.detailed.json" "${file_fmt}" "${jq_query_ids}"
    log "INFO: detailed list of ${object_type} entities split by ${split_function}()"

    if [ -n "${exit_callback_function}" ]; then
        ${exit_callback_function} "$@"
        log "INFO: ${exit_callback_function}() callback succeeded"       
    fi
    log "INFO: ${object_type} entities dumped"
}

function ostack_dump_domain() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "domain" ".id"
}

function ostack_dump_flavor() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "flavor" ".id" "--long"
}

function ostack_dump_image() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "image" ".id" "--long"
}


function ostack_dump_user() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "user" '.domain_id + " " + .id' "--long"
}

function get_ostack_project_domain_association() {
    local raw_entities_dir="$1"

    source <(cat "${raw_entities_dir}/projects.brief.json" | \
             jq -r '.[] |.ID  + " " +."Domain ID"' | \
             tr '[:upper:]' '[:lower:]' | \
             awk '{printf("OSTACK_PRJ_TO_DOMAIN[%s]=\"%s\"\n",$1, $2)}')
}

function ostack_dump_project() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "project" '.domain_id + " " + .id' "--long" "get_ostack_project_domain_association"
}


function ostack_dump_quota() {
    local raw_entities_dir="$1"
    local file_fmt="$2"

    if [ ! -s "${raw_entities_dir}/projects.brief.json" ]; then
        ostack_cli_ro project list --long > "${raw_entities_dir}/projects.brief.json"
    fi

    local entity_count="$(cat "${raw_entities_dir}/projects.brief.json" | jq '. | length')"
    log "INFO: ${entity_count} quota entities found"
    [ "${entity_count}" == "0" ] && \
      return 0

    cat "${raw_entities_dir}/projects.brief.json" | jq -r '.[].ID' | \
      awk '{print "quota show " $1}' | ostack_cli_ro > "${raw_entities_dir}/quotas.detailed.json"
    
    # TODO: race-condition exists here as quota details does not come with project_id
    #   and ostack may have changed since projects were dumped (<dir>/projects.brief.json)
    local file_names="$(cat "${raw_entities_dir}/projects.brief.json" | jq -r '.[] | ."Domain ID" + " " + .ID' | \
                        gawk -v "fmt=${file_fmt}\n" -f "${STREAM_PRINTF_TOOL}")"

    concat_json_split_on_file_names "${raw_entities_dir}/quotas.detailed.json" "${file_names}"
}

function ostack_dump_server() {
    local raw_entities_dir="$1"
    local file_fmt="$2"

    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "server" '.project_id + " " + .id' \
      "--long --all-projects --limit 100000" "" "concat_json_split_detect_domain"
    # --limit was originally -1 (no limit), but stopped working with error
    # BadRequestException: 400: Client Error for url: https://compute.ostrava.openstack.cloud.e-infra.cz/v2.1/3e6ced06901c451a82292c742075680a/servers/detail?limit=-1&deleted=False&all_tenants=True, Invalid input for query parameters limit. Value: -1. '-1' does not match '^[0-9]*$'
}

function ostack_dump_mapping() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "mapping" ".id"
}

function ostack_dump_volume() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "volume" ".id" "--all-projects"
}

function ostack_dump_service() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "service" ".id" "--long"
}

function ostack_dump_region() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "region" ".region"
}

function ostack_dump_hypervisor() {
    local raw_entities_dir="$1"
    local file_fmt="$2"
    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "hypervisor" ".id" "--long"
}

function ostack_dump_loadbalancer() {
    local raw_entities_dir="$1"
    local file_fmt="$2"

    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "loadbalancer" '.project_id + " " + .id' \
      "" "" "concat_json_split_detect_domain" ".[].id"
}

function ostack_dump_floating_ip() {
    local raw_entities_dir="$1"
    local file_fmt="$2"

    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "floating-ip" '.project_id + " " + .id' \
      "--long" "" "concat_json_split_detect_domain"
}

function ostack_dump_subnet() {
    local raw_entities_dir="$1"
    local file_fmt="$2"

    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "subnet" '.project_id + " " + .id' \
      "--long" "" "concat_json_split_detect_domain"
}

function ostack_dump_network() {
    local raw_entities_dir="$1"
    local file_fmt="$2"

    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "network" '.project_id + " " + .id' \
      "--long" "" "concat_json_split_detect_domain"
}

function ostack_dump_router() {
    local raw_entities_dir="$1"
    local file_fmt="$2"

    ostack_dump_xyz "${raw_entities_dir}" "${file_fmt}" "router" '.project_id + " " + .id' \
      "--long" "" "concat_json_split_detect_domain"
}

# main steps
# ---------------------------------------------------------------------------
STEP_NAME="openstack initial authentication test"
ostack_cli_ro versions show &>/dev/null

STEP_NAME="output directory ${DUMP_ROOTDIR} creation"
test -d "${DUMP_ROOTDIR}/__raw" || mkdir -p "${DUMP_ROOTDIR}/__raw"

log "INFO: Plan to dump: ${OBJECTS}"

for i_entity in ${OBJECTS}; do
    log "INFO: Dump ${i_entity} entities"
    STEP_NAME="openstack ${i_entity} export"
    "ostack_dump_${i_entity//-/_}" "${DUMP_ROOTDIR}/__raw" "${DUMP_ROOTDIR}/${OBJECT_FILE_FMT[${i_entity}]}"
done

STEP_NAME="Success"
