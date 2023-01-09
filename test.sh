#!/bin/bash

# be compatible for different operations

function check() {
  exit 1
}

function compatible_jq() {
  local params=("${@}")
  local jq_content=${params[0]}
  # 加括号表示数组赋值
  local options=("${params[@]:1}")
  local jq_result
  local jq_error
  local OS
  OS=$(uname)
  if [[ "${OS}" == *"MINGW"* ]]; then
    chmod +x "jq.exe"
    # windows
    jq_result=$(echo "${jq_content}" | ./jq "${options[@]}" 2>&1)
    echo "enter windows" >&1
  else
    echo "enter non windows" >&1
    jq_result=$(echo "${jq_content}" | jq "${options[@]}" 2>&1)
  fi
  if [[ $? -ne 0 ]]; then
    # 如果上面的jq没有将错误重定向到stdout的话，那么jq_result就是个空串（因为jq命令执行异常，输出到stderr之后，返回值就是个空串；如果想接收异常信息，那么就得把stderr重定向到&1）
    jq_error="${jq_result}"
    handle_jq_parse_error "$jq_error"
    exit 1
  fi
  echo "${jq_result}"
}

function handle_jq_parse_error() {
  local jq_error="${1}"
  printf "\033[31mError: gitlab服务器内部错误，无法正确解析响应内容！请稍后重试~ \033[0m\n" >&2
  echo "my jq parse error：$jq_error" >&2
}

# test jq
project_resp='[{"id": "111"}]'
COMPATIBLE_PROJECT_ID=$(compatible_jq "${project_resp}" -r '.[0].id')
#PROJECT_ID=$(echo "$project_resp" | jq -r '.[0].id' 2>&1)
echo "$COMPATIBLE_PROJECT_ID"
echo "aaa"
echo "bbb"
#echo "${COMPATIBLE_PROJECT_ID}"
#echo "${PROJECT_ID}"
