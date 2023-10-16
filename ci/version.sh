#!/usr/bin/env bash

# Get project version
# Usage:
# * get-version <changelog-version-file>

CHANGELOG_FILE="$1"

changelog_version=$(grep -E '^##[ \t]+\[.+\]' "${CHANGELOG_FILE}" | \
                    awk '{print substr($2,2,length($2)-2)}' | grep -v '[Uu]nreleased' | head -1)


if [[ "${CI_COMMIT_TAG}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    if [ "${CI_COMMIT_TAG}" != "${changelog_version}" -a "${CI_COMMIT_TAG}" != "v${changelog_version}" ]; then
        echo "Cannot get project version as tag claims version ${CI_COMMIT_TAG} but changelog version is ${changelog_version}"
        exit 1
    fi
    echo "${changelog_version}"
else
    echo "${changelog_version}_${CI_COMMIT_SHA}_${CI_PIPELINE_ID}"
fi
