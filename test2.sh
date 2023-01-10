#!/bin/bash
printf "\033[33m温馨提示：可以同时选择多个项目，以及多个目标分支，将根据同一个源分支，同时对多个代码仓库及其多个目标分支提合并请求。\n\n\033[0m"
resp=$(curl -s "https://code.choerodon.com.cn/api/v4/projects?private_token=glpat-2ba-xoCxqZaZ7GyN35mi&search=o2-inventory&search_by_name=true&simple")
r2=$(curl -s -X POST "http://10.211.144.169:8080/v1/shell/project-info")
printf "xxxxx\n"
echo "$resp"

aaa=$(echo "$resp" | jq -r '.[5]'.id)
echo "$aaa"

function check_empty() {
  local param=$1
  if [[ -z "$param" || "$param" =~ ^[\ ]*$ ]]; then
    echo "true"
  else
    echo "false"
  fi
}

if [[ $(check_empty "$aaa") == "true"  || "$aaa" == "null" ]]; then
  echo "empty"
fi
