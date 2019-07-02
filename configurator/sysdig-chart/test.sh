#!/bin/bash

set -euo pipefail
. /sysdig-chart/framework.sh

IGNORED_FIELDS=(
  sysdigcloud.default.user.password
  redis.password
  mysql.root.password
  mysql.password
)

function sanitize() {
  for field in "${IGNORED_FIELDS[@]}"; do
    sed -ie "/${field}/d" "$1"
  done
}

# concatenates yaml files and remove objects of kind secret from the file.
function concat_config() {
  local source_directory="$1"
  local destination_file="$2"

  # truncate the file to be concatenated to before concatenating
  echo > "$destination_file"
  for file in "$source_directory"/*; do
    if [[ -f "$file" ]]; then
      cat "$file" >> "$destination_file"
    fi
  done

  local tmp_file
  tmp_file=$(mktemp)
  yq -r 'select(.kind != "Secret")' "$destination_file" > "$tmp_file"
  sanitize "$tmp_file"
  mv "$tmp_file" "$destination_file"
}

function run_tests() {
  for directory in /sysdig-chart/tests/resources/*/; do
    if [[ -d "$directory" ]]; then
      rm -rf /manifests/*
      cp "$directory/values.yaml" /sysdig-chart/values.yaml
      /sysdig-chart/generate_templates.sh
      TMP_FILE=$(mktemp)
      concat_config /manifests/generated/ "$TMP_FILE"
      if ! diff -w "$directory/sysdig.json" "$TMP_FILE"; then
        log error "generated config does not match ${directory}sysdig.json"
        exit 1
      fi
    fi
  done
}

function run_uber_tar_tests() {
  local uber_tar=/manifests/uber_archive.tar.gz
  if [[ ! -x "$uber_tar" ]]; then
    log error "$uber_tar has not been generated, please generate before running tests"
  fi
  cd /manifests
  NO_RUN=true "$uber_tar"

  for image in $(yq -r '.spec.template.spec | {containers: .containers[]?}.containers.image' /manifests/generated/*.yaml); do
    if [[ -z "$(docker images image)" ]]; then
      log error "Expected uber_tar to have loaded image: '${image}', but it did not"
      exit 1
    fi
  done
}

function config_gen() {
  for directory in /sysdig-chart/tests/resources/*/; do
    if [[ -d "$directory" ]]; then
      rm -rf /manifests/*
      cp "$directory/values.yaml" /sysdig-chart/values.yaml
      /sysdig-chart/generate_templates.sh
      concat_config /manifests/generated/ "$directory/sysdig.json"
    fi
  done
}

ARG=${1:-}
if [[ "${ARG}" == "config_gen" ]]; then
  config_gen
elif [[ "${ARG}" == "uber_tests" ]]; then
  run_uber_tar_tests
else
  run_tests
fi
