#!/usr/bin/env bash
# XNode 通用工具函数（交互风格参考 V2bX-script）

# V2bX 风格颜色
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly PLAIN='\033[0m'

# 需要 root 权限
require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "错误: 请使用 root 权限运行 (sudo bash xnode)"
    exit 1
  fi
}

# 检测命令是否存在
cmd_exists() {
  command -v "$1" &>/dev/null
}

# 生成 UUID
gen_uuid() {
  if cmd_exists sing-box; then
    sing-box generate uuid 2>/dev/null && return
  fi
  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    cat /proc/sys/kernel/random/uuid
    return
  fi
  uuidgen 2>/dev/null || openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/'
}

# 生成随机密码
gen_password() {
  local len="${1:-16}"
  openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "${len}"
}

# 生成 short_id (8 hex)
gen_short_id() {
  openssl rand -hex 4
}

# 读取用户输入
prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local result=""
  if [[ -n "${default}" ]]; then
    read -rp "${prompt} [${default}]: " result
    echo "${result:-${default}}"
  else
    read -rp "${prompt}: " result
    echo "${result}"
  fi
}

# 确认 y/n（支持 V2bX 默认参数: confirm "消息" "y"）
confirm() {
  local msg="$1"
  local default="${2:-}"
  local ans=""
  if [[ -n "${default}" ]]; then
    read -rp "${msg} [默认${default}]: " ans
    ans="${ans:-${default}}"
  else
    read -rp "${msg} [y/N]: " ans
  fi
  [[ "${ans}" == "y" || "${ans}" == "Y" ]]
}

# 信息 / 成功 / 警告 / 错误
info()    { echo -e "${YELLOW}[INFO]${PLAIN} $*"; }
success() { echo -e "${GREEN}[OK]${PLAIN} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${PLAIN} $*"; }
error()   { echo -e "${RED}[ERR]${PLAIN} $*" >&2; }

# 按回车返回主菜单（V2bX before_show_menu）
before_show_menu() {
  echo
  echo -en "${YELLOW}按回车返回主菜单: ${PLAIN}"
  read -r
}

# 暂停
pause() {
  before_show_menu
}

# 检测 IPv6（参考 V2bX）
check_ipv6_support() {
  if ip -6 addr 2>/dev/null | grep -q "inet6"; then
    echo "1"
  else
    echo "0"
  fi
}

# 监听地址：有 IPv6 用 ::，否则 0.0.0.0
get_listen_ip() {
  local saved
  saved="$(json_get "${XNODE_CONFIG}" '.listen_ip // ""')"
  if [[ -n "${saved}" ]]; then
    echo "${saved}"
    return
  fi
  if [[ "$(check_ipv6_support)" == "1" ]]; then
    echo "::"
  else
    echo "0.0.0.0"
  fi
}

# 保存监听地址到配置
save_listen_ip() {
  local ip
  ip="$(get_listen_ip)"
  json_set "${XNODE_CONFIG}" ".listen_ip = \"${ip}\""
  echo "${ip}"
}

# 检测系统
detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    echo "${ID}-${VERSION_ID}"
  else
    echo "unknown"
  fi
}

# 检测架构
detect_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "unsupported" ;;
  esac
}

# 检查域名是否解析到本机
domain_points_here() {
  local domain="$1"
  local local_ip public_ip resolved
  local_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  public_ip="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  resolved="$(getent ahostsv4 "${domain}" 2>/dev/null | awk '{print $1; exit}')"
  [[ -n "${resolved}" ]] && { [[ "${resolved}" == "${local_ip}" ]] || [[ "${resolved}" == "${public_ip}" ]]; }
}

# JSON: 读取 config 字段
json_get() {
  local file="$1"
  local filter="$2"
  jq -r "${filter}" "${file}" 2>/dev/null
}

# JSON: 写入 config
json_set() {
  local file="$1"
  local filter="$2"
  local tmp
  tmp="$(mktemp)"
  jq "${filter}" "${file}" > "${tmp}" && mv "${tmp}" "${file}"
}

# 确保 JSON 文件存在
ensure_json_file() {
  local file="$1"
  local default="$2"
  if [[ ! -f "${file}" ]]; then
    mkdir -p "$(dirname "${file}")"
    echo "${default}" > "${file}"
  fi
}

# 清屏并显示标题
show_banner() {
  clear
  echo -e "${GREEN}XNode 中文节点管理器${PLAIN} — 适配 Xboard-Node / sing-box"
  echo -e "${YELLOW}参考交互: V2bX-script${PLAIN} | ${YELLOW}https://github.com/wyx2685/V2bX${PLAIN}"
  echo "-----------------------------------------"
  echo
}

# 选择菜单项
menu_select() {
  local prompt="$1"
  shift
  local options=("$@")
  local i choice
  for i in "${!options[@]}"; do
    echo "  $((i + 1)). ${options[$i]}"
  done
  echo "  0. 返回"
  read -rp "${prompt}: " choice
  if [[ "${choice}" == "0" ]]; then
    return 1
  fi
  if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
    REPLY=$((choice - 1))
    return 0
  fi
  warn "无效选择"
  return 1
}
