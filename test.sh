#!/bin/bash

# be compatible for different operations
function compatible_jq() {
#  local options="$*"
  local jq_result
  if [[ "${OS}" == *"MINGW"* ]]; then
    # windows
    jq_result=$(./jq "${@}")
    echo "enter windows" >&2
  else
    echo "enter non windows111" >&2
    jq_result=$(jq "${@}")
  fi
  echo "${jq_result}"
}

# test jq
project_resp='{"id": "111"}'
option='.id'
PROJECT_ID=$(echo "$project_resp" | compatible_jq -r  "${option}" 2>&1)
echo "${PROJECT_ID}"