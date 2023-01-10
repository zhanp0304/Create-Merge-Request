#!/bin/bash
# shellcheck disable=SC2181

#TODO: (鲁棒性）异常输入测试用例补充：源分支不存在、目标分支不存在、审批人不存在（查无此人）、审批人无权限(无权限则报错，高级用法，未实现）

DEFAULT_PROJECTS=(
  "o2-consignment-b2c"
  "o2-tmall-integration"
  "o2-jingdong-integration"
  "o2-public-platform-integration"
  "o2-inventory"
  "o2-cms"
  "o2-metadata"
  "o2-cms"
  "o2-marketing-b2c"
  "o2-starter"
  "o2-monitor")

# Don't forget to make desensitization processing for FEMALE_MEMBERS
YOUR_ACCESS_TOKEN="glpat-2ba-xoCxqZaZ7GyN35mi"
DEFAULT_ASSIGN_NAME="程厚霖"
FEMALE_MEMBERS=("柳" "欢欢")

DEFAULT_PROJECT_FETCH_API="https://%s/api/v4/projects?private_token=%s&search=%s"
DEFAULT_ASSIGNEE_FETCH_API="https://%s/api/v4/users?private_token=%s&search=%s"
DEFAULT_SUBMIT_MERGE_REQUEST_API="https://%s/api/v4/projects/%s/merge_requests"

# Set the GitLab hostname and access token
DEBUG_OPEN_FLAG=${1:-"n"}
GITLAB_HOST=${2:-"code.choerodon.com.cn"}
ACCESS_TOKEN=${3:-"${YOUR_ACCESS_TOKEN}"}
DEFAULT_ASSIGN_NAME=${4:-"${DEFAULT_ASSIGN_NAME}"}
OS=$(uname)
WINDOWS_FLAG=0
if [[ "${OS}" == *"MINGW"* ]]; then
  WINDOWS_FLAG=1
else
  WINDOWS_FLAG=0
fi

function debug_echo() {
  local echo_content="$1"
  if [[ "$DEBUG_OPEN_FLAG" == "y" || "$DEBUG_OPEN_FLAG" == "Y" ]]; then
    # 【注意，此处有坑点：不要把>&2改为>&1，否则会导致debug模式下日志打印乱序问题】
    printf "\n" >&2
    echo -e "\033[33m${echo_content}\033[0m" >&2
  fi
}

function print_declaring() {
  printf "\n"
  printf "\033[33m作者：zhanpeng.jiang@hand-china.com\n\033[0m"
  printf "\033[33m声明：本脚本致力于为O2降本增效，解决了猪齿鱼gitlab界面需要重复操作多次的痛点问题，尤其适用于需要同时对多个代码仓库提合并请求的场景。\n\n\033[0m"
  printf "\033[33m温馨提示：可以同时选择多个项目，以及多个目标分支，将根据同一个源分支，同时对多个代码仓库及其多个目标分支提合并请求。\n\n\033[0m"
}

function print_project_info() {
  local num=${#DEFAULT_PROJECTS[@]}
  for ((i = 0; i < "${num}"; i++)); do
    echo -e "\033[032m $i: ${DEFAULT_PROJECTS["$i"]}        \033[0m"
  done
}

function check_empty() {
  local param=$1
  if [[ -z "$param" || "$param" =~ ^[\ ]*$ ]]; then
    echo "true"
  else
    echo "false"
  fi
}

function exit_check() {
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
}

# only for jq test
function jq_test() {
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

function auto_install_tool() {
  local arch
  # check if jq is installed
  jq_test
  if [ $? -ne 0 ]; then
    # jq is not installed
    # check the operating system type
    case "${OS}" in
    "Linux")
      # install jq on Linux
      apt-get install -y jq >/dev/null
      ;;
    "Darwin")
      # install jq on macOS
      arch=$(arch)
      if [[ "${arch}" == "arm64" ]]; then
        arch -x86_64 brew install jq >/dev/null
      else
        brew install jq >/dev/null
      fi
      ;;
    esac

    if [[ "${OS}" == *"MINGW"* ]]; then
      WINDOWS_FLAG=1
    fi

    # check if jq is installed successfully
    jq_test
    if [ $? -ne 0 ]; then
      if [[ ${WINDOWS_FLAG} == 1 ]]; then
        printf "\033[31mError: 必要组件jq.exe不存在，请检查当前脚本所在文件夹内是否包含必需的文件jq.exe! \033[0m\n" >&2
      else
        printf "\033[31mError: jq自动安装失败，请手动安装必要软件jq! \033[0m\n" >&2
      fi
      # exit for jq installation failed
      exit 1
    fi
  fi
}

function handle_jq_parse_error() {
  local jq_error="${1}"
  printf "\033[31mError: gitlab服务器内部错误，jq无法正确解析响应内容！请稍后重试~ \033[0m\n" >&2
  debug_echo "jq parse error：$jq_error"
}

# enhanced jq to be compatible for different operating system, which can handle the jq parse error
function compatible_jq() {
  local jq_result
  local jq_error

  # 【学习用注释：使用参数数组对jq进行包装增强】
  local params=("${@}")
  local jq_content=${params[0]}
  local jq_options=("${params[@]:1}")

  if [[ "${OS}" == *"MINGW"* ]]; then
    chmod +x "jq.exe"
    if [[ $? -ne 0 ]]; then
      printf "\033[31mError: 必要组件jq.exe不存在或当前无权限操作jq，请检查当前脚本所在文件夹内是否包含必需的文件jq.exe或检查用户权限! \033[0m\n" >&2
      exit 1
    fi
    # windows
    jq_result=$(echo "${jq_content}" | ./jq "${jq_options[@]}" 2>&1)
    debug_echo "compatible_jq: enter window system" >&1
  else
    debug_echo "compatible_jq: enter non windows" >&1
    jq_result=$(echo "${jq_content}" | jq "${jq_options[@]}" 2>&1)
  fi
  if [[ $? -ne 0 ]]; then
    # 【学习用注释】如果上面的jq没有将错误重定向到stdout的话，那么jq_result就是个空串（因为jq命令执行异常，输出到stderr之后，返回值就是个空串；
    # 如果想接收异常信息，那么就得把stderr重定向到&1）
    jq_error="${jq_result}"
    handle_jq_parse_error "$jq_error"
    exit 1
  fi
  echo "${jq_result}"
}

function curl_resp_success_check() {
  local curl_resp="${1}"
  local http_status_code
  http_status_code=$(echo "${curl_resp}" | grep -oE 'HTTP/[^[:space:]]+[[:space:]]+[[:digit:]]+' | awk '{print $2}')
  if [[ "${http_status_code}" -ge 200 && "$http_status_code" -lt 300 ]]; then
    # curl success
    echo "true"
    return
  elif [[ "${http_status_code}" == "409" ]]; then
    printf "\033[31mError: 重复请求！您已经提交过一次合并请求了，请先到猪齿鱼gitlab界面手动处理上一个请求后重试 \033[0m\n" >&2
    exit 1
  fi
  printf "\033[31mError: http_status_code:[%s] curl请求失败, 可能是gitlab服务器内部错误！请稍后重试~ \033[0m\n" "$http_status_code" >&2
  # curl failed
  echo "false"
}

function fetch_project_id() {
  debug_echo "enter -> fetch_project_id"
  local project_fetch_url
  local PROJECT_NAME=$1
  local project_resp
  local PROJECT_ID

  if [[ $(check_empty "$PROJECT_NAME") == "true" ]]; then
    printf "\033[31mError: 您选择的项目不允许为空，请重新运行脚本后正确选择你拥有权限的项目 \033[0m\n" >&2
    exit 1
  fi

  # test curl
  project_fetch_url=$(printf "${DEFAULT_PROJECT_FETCH_API}" "$GITLAB_HOST" "$ACCESS_TOKEN" "$PROJECT_NAME")
  debug_echo "start curl: ${project_fetch_url}"
  # Get the project ID from the project name
  project_resp=$(curl -s "${project_fetch_url}")
  PROJECT_ID=$(compatible_jq "$project_resp" -r '.[0].id')
  exit_check

  if [[ $(check_empty "$PROJECT_ID") == "true" ]]; then
    printf "\033[31mError: 获取项目ID失败，请重新运行脚本后正确选择你拥有权限的项目 \033[0m\n" >&2
    exit 1
  fi

  debug_echo "curl to get PROJECT_ID: $PROJECT_ID  successfully!"
  echo "$PROJECT_ID"
}

function fetch_assignee_id() {
  debug_echo "enter -> fetch_assignee_id"
  local ASSIGNEE_NAME=$1
  local assignee_fetch_url
  local ASSIGNEE_ID
  local project_resp

  if [[ $(check_empty "ASSIGNEE_NAME") == "true" ]]; then
    printf "\033[31mError: 您选择的审批人不允许为空，请重新运行脚本后正确选择团队中有该项目权限的审批人 \033[0m\n" >&2
    exit 1
  fi
  # test curl
  assignee_fetch_url=$(printf "${DEFAULT_ASSIGNEE_FETCH_API}" "$GITLAB_HOST" "$ACCESS_TOKEN" "$ASSIGNEE_NAME")
  debug_echo "start curl: ${assignee_fetch_url}"
  project_resp=$(curl -s "${assignee_fetch_url}")
  ASSIGNEE_ID=$(compatible_jq "$project_resp" -r '.[0].id')
  exit_check

  if [[ $(check_empty "$ASSIGNEE_ID") == "true" ]]; then
    printf "\033[31mError: 获取审批人ID失败，请重新运行脚本后正确选择团队中有该项目权限的审批人 \033[0m\n" >&2
    exit 1
  fi

  debug_echo "curl to get ASSIGNEE_ID: ${ASSIGNEE_ID}  successfully!"
  echo "$ASSIGNEE_ID"
}

function render_assignee_nick_name() {
  local assignee_name="$1"

  if [[ $WINDOWS_FLAG == 1 ]]; then
    # really hard to curl with Chinese in Windows, so transform -> English
    echo ""
  else
    if [[ "$assignee_name" == "孙柳" ]]; then
      echo "柳哥柳哥"
    elif [[ " ${FEMALE_MEMBERS[*]} " =~ ${assignee_name} ]]; then
      echo "${assignee_name}女士"
    else
      echo "${assignee_name}大哥"
    fi
  fi
}

function render_merge_request_title() {
  local assignee_name="$1"
  local nick_name
  nick_name=$(render_assignee_nick_name "${assignee_name}")
  if [[ $WINDOWS_FLAG == 1 ]]; then
    # really hard to curl with Chinese in Windows, so transform -> English
    echo "Hello there! Would you mind helping me merge this pretty code? Thank you in advance!"
  else
    echo "${nick_name}，能帮我合下代码吗，谢谢！"
  fi
}

function submit_merge_request() {
  debug_echo "enter -> submit_merge_request"
  local PROJECT_ID=$1
  local ASSIGNEE_ID=$2
  local SOURCE_BRANCH=$3
  local TARGET_BRANCH=$4
  local PROJECT_NAME=$5
  local ASSIGNEE_NAME=$6
  local ORIGIN_ASSIGNEE_NAME=$7
  local curl_resp
  local API_ENDPOINT
  local title
  title=$(render_merge_request_title "${ORIGIN_ASSIGNEE_NAME}")

  # Set the API endpoint and create the merge request
  API_ENDPOINT=$(printf "${DEFAULT_SUBMIT_MERGE_REQUEST_API}" "$GITLAB_HOST" "$PROJECT_ID")

  debug_echo "----------------------------------------"
  debug_echo "current merge request url: ${API_ENDPOINT}"
  debug_echo "PROJECT_NAME: ${PROJECT_NAME}"
  debug_echo "ASSIGNEE_ID: ${ASSIGNEE_ID}"
  debug_echo "SOURCE_BRANCH: ${SOURCE_BRANCH}"
  debug_echo "TARGET_BRANCH: ${TARGET_BRANCH}"
  debug_echo "ASSIGNEE_NAME: ${ORIGIN_ASSIGNEE_NAME}"
  debug_echo "title: $title"
  debug_echo "----------------------------------------"

  curl_resp=$(curl -X POST -i "$API_ENDPOINT" \
    --header "PRIVATE-TOKEN: $ACCESS_TOKEN" \
    --form "source_branch=$SOURCE_BRANCH" \
    --form "target_branch=$TARGET_BRANCH" \
    --form "remove_source_branch=false" \
    --form "assignee_id=$ASSIGNEE_ID" \
    --form "title=$title")
  if [[ $(curl_resp_success_check "${curl_resp}") == "true" ]]; then
    printf "\033[32m项目：%s 代码合并请求提交成功!! \n\033[0m" "$PROJECT_NAME"
  else
    printf "\033[31mError: 项目：%s 代码合并请求提交失败，请重新运行脚本后重试 \n\033[0m" "$PROJECT_NAME" >&2
    exit 1
  fi
}

while true; do
  print_declaring
  auto_install_tool
  print_project_info

  PROJECT_NAME=""
  SOURCE_BRANCH=""
  TARGET_BRANCH=""
  ASSIGNEE_NAME="$DEFAULT_ASSIGN_NAME"
  pick_projects=()
  target_branches=()
  assignee_name_user_input=""

  # check access_token
  if [[ $(check_empty "$ACCESS_TOKEN") == "true" ]]; then
    printf "\033[31mError: ACCESS_TOKEN不可为空，请在脚本中维护ACCESS_TOKEN \n\033[0m"
    exit 1
  fi

  # TODO: 需要对read进行错误容忍的处理，以及非法输入的语法报错，或者让用户重新输入，read循环打印直到用户输入正确才往下走,结合下面的print进行错误警告
  # printf "\033[31mError: Invalid input. Please try again.\033[0m\n"
  printf "\n"
  read -p $'\033[34m请选择项目序号（若要选择多个则以空格分隔输入）: \033[0m' -r -a pick_projects
  read -p $'\033[34m请输入源分支名: \033[0m' -r SOURCE_BRANCH
  read -p $'\033[34m请输入目标分支名（若要选择多个则以空格分隔输入）: \033[0m' -r -a target_branches
  #  read -p $'\033[34m请输入审批人名称（直接回车将默认分配给'"${ASSIGNEE_NAME}"$'进行合并）: \033[0m' -r assignee_name_user_input
  read -p $'\033[34m请输入审批人名称（直接回车将默认分配'"${ASSIGNEE_NAME}"$'进行合并)\033[0m' -r assignee_name_user_input
  if [[ -n "$assignee_name_user_input" && ! "$assignee_name_user_input" =~ ^[\ ]*$ ]]; then
    debug_echo "pick assignee name: $assignee_name_user_input"
    ASSIGNEE_NAME="$assignee_name_user_input"
  fi

  # percent encoding formats the ASSIGNEE_NAME
  ORIGIN_ASSIGNEE_NAME="${ASSIGNEE_NAME}"
  ASSIGNEE_NAME=$(echo "$ASSIGNEE_NAME" | xxd -p -c 20 | tr -d '\n' | sed 's/\(..\)/%\1/g')
  ASSIGNEE_NAME=$(echo "$ASSIGNEE_NAME" | sed 's/%0a/%20/g' | sed 's/%0d/%20/g')
  debug_echo "escape_assignee_name: ${ASSIGNEE_NAME}"

  for project in "${pick_projects[@]}"; do
    for target_branch in "${target_branches[@]}"; do
      PROJECT_NAME=${DEFAULT_PROJECTS[${project}]}
      TARGET_BRANCH=${target_branch}
      # fetch project_id
      PROJECT_ID=$(fetch_project_id "$PROJECT_NAME")
      exit_check
      # fetch assignee_id
      ASSIGNEE_ID=$(fetch_assignee_id "$ASSIGNEE_NAME")
      exit_check
      #submit merge request
      submit_merge_request "$PROJECT_ID" "$ASSIGNEE_ID" "$SOURCE_BRANCH" "$TARGET_BRANCH" "$PROJECT_NAME" "$ASSIGNEE_NAME" "${ORIGIN_ASSIGNEE_NAME}"
      exit_check
    done
  done
done
