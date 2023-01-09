#!/bin/bash

# be compatible for different operations

FEMALE_MEMBERS=("孙柳" "汪欢欢")

function render_assignee_nick_name() {
  local assignee_name="$1"
  if [[ "$assignee_name" == "孙柳" ]]; then
    echo "柳哥"
  elif [[ " ${FEMALE_MEMBERS[*]} " =~ ${assignee_name} ]]; then
    echo "${assignee_name}女士"
  else
    echo "${assignee_name}大哥"
  fi
}

function check() {
  exit 1
}

# only for jq test
function jq_test() {
  local OS
  OS=$(uname)
  if [[ "${OS}" == *"MINGW"* ]]; then
    if [[ $? -ne 0 ]]; then
      printf "\033[31mError: 必要组件jq.exe不存在或当前无权限操作jq，请检查当前脚本所在文件夹内是否包含必需的文件jq.exe或检查用户权限! \033[0m\n" >&2
      exit 1
    fi
    ./jq --version >/dev/null 2>&1
  else
    jq --version >/dev/null 2>&1
  fi
  return $?
}

# enhanced jq to be compatible for different operating system, which can handle the jq parse error
function compatible_jq() {
  local jq_result
  local jq_error
  local OS

  local params=("${@}")
  local jq_content=${params[0]}
  local jq_options=("${params[@]:1}")

  OS=$(uname)
  if [[ "${OS}" == *"MINGW"* ]]; then
    chmod +x "jq.exe"
    if [[ $? -ne 0 ]]; then
      printf "\033[31mError: 必要组件jq.exe不存在或当前无权限操作jq，请检查当前脚本所在文件夹内是否包含必需的文件jq.exe或检查用户权限! \033[0m\n" >&2
      exit 1
    fi
    # windows
    jq_result=$(echo "${jq_content}" | ./jq "${jq_options[@]}" 2>&1)
    echo "enter windows" >&1
  else
    echo "enter non windows" >&1
    jq_result=$(echo "${jq_content}" | jq "${jq_options[@]}" 2>&1)
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

function exit_check() {
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
}

# test jq
project_resp='[{"id": "111"}]'

jq_test
#compatible_jq --version
#jq --version

name=$(render_assignee_nick_name "柳")
echo "$name"

COMPATIBLE_PROJECT_ID=$(compatible_jq "${project_resp}" -r '.[0].id')
#PROJECT_ID=$(echo "$project_resp" | jq -r '.[0].id' 2>&1)
echo "$COMPATIBLE_PROJECT_ID"
check_res=$(check)
exit_check
echo "aaa"
echo "bbb"
#echo "${COMPATIBLE_PROJECT_ID}"
#echo "${PROJECT_ID}"
