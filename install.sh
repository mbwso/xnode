#!/usr/bin/env bash
# 管道安装检测（wget | bash 时 BASH_SOURCE 为空）
_IS_PIPE=0
[[ -z "${BASH_SOURCE[0]:-}" ]] && _IS_PIPE=1

# 修复 Windows CRLF（仅本地文件模式）
if [[ "${_IS_PIPE}" -eq 0 ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  grep -q $'\r' "${BASH_SOURCE[0]}" 2>/dev/null && sed -i 's/\r$//' "${BASH_SOURCE[0]}" && exec bash "${BASH_SOURCE[0]}" "$@"
fi
# XNode 一键安装（支持一行命令远程安装，用法同 V2bX-script）
#
# wget -qO- "https://raw.githubusercontent.com/mbwso/xnode/main/install.sh" | tr -d '\r' | bash
# 或: wget -N .../install.sh && sed -i 's/\r$//' install.sh && bash install.sh
#
# 可选环境变量:
#   XNODE_REPO=用户名/xnode   GitHub 仓库
#   XNODE_BRANCH=main            分支名

set -euo pipefail

INSTALL_DIR="/opt/xnode"
BIN_PATH="/usr/bin/xnode"

# ========== 发布前请改成你的 GitHub 仓库 ==========
XNODE_REPO="${XNODE_REPO:-mbwso/xnode}"
XNODE_BRANCH="${XNODE_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${XNODE_REPO}/${XNODE_BRANCH}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
fail() { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

# 检测是否为「只下载了 install.sh」的远程安装
need_download_repo() {
  [[ ! -f "${1}/xnode" ]] || [[ ! -d "${1}/core" ]]
}

# 从 GitHub 拉取完整项目到 INSTALL_DIR
download_repo() {
  local tmp repo_dir archive_root
  log "从 GitHub 下载 XNode: ${XNODE_REPO} (${XNODE_BRANCH})..."

  if [[ "${XNODE_REPO}" == *"YOUR_USERNAME"* ]]; then
    fail "请先在 install.sh 中设置 XNODE_REPO，或导出: export XNODE_REPO=mbwso/xnode"
  fi

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  if command -v git &>/dev/null; then
    git clone --depth 1 --branch "${XNODE_BRANCH}" \
      "https://github.com/${XNODE_REPO}.git" "${tmp}/repo" 2>/dev/null \
      || fail "git clone 失败，请检查仓库地址与分支"
    repo_dir="${tmp}/repo"
  else
    log "未安装 git，使用 tarball 下载..."
    curl -fsSL "https://github.com/${XNODE_REPO}/archive/refs/heads/${XNODE_BRANCH}.tar.gz" \
      -o "${tmp}/src.tar.gz" || fail "下载失败，请检查网络或仓库是否存在"
    tar -xzf "${tmp}/src.tar.gz" -C "${tmp}"
    archive_root="$(find "${tmp}" -maxdepth 1 -type d -name '*-*' | head -1)"
    [[ -n "${archive_root}" ]] || fail "解压失败"
    repo_dir="${archive_root}"
  fi

  mkdir -p "${INSTALL_DIR}"
  rm -rf "${INSTALL_DIR:?}"/*
  # 兼容仓库根目录即项目 / 或子目录 xnode/（旧名 xnode-cn 仍支持）
  if [[ -f "${repo_dir}/xnode" ]]; then
    cp -a "${repo_dir}/." "${INSTALL_DIR}/"
  elif [[ -f "${repo_dir}/xnode/xnode" ]]; then
    cp -a "${repo_dir}/xnode/." "${INSTALL_DIR}/"
  elif [[ -f "${repo_dir}/xnode-cn/xnode" ]]; then
    cp -a "${repo_dir}/xnode-cn/." "${INSTALL_DIR}/"
  else
    fail "仓库中未找到 xnode 主程序，请确认目录结构"
  fi

  ok "项目文件已下载到 ${INSTALL_DIR}"
}

# 安装 /usr/bin/xnode 启动器（同 V2bX 安装 V2bX.sh）
install_bin_launcher() {
  log "安装管理命令 xnode ..."
  if curl -fsSL --connect-timeout 15 --retry 2 \
    "${RAW_BASE}/xnode.sh" -o "${BIN_PATH}"; then
    chmod +x "${BIN_PATH}"
  elif [[ -f "${INSTALL_DIR}/xnode.sh" ]]; then
    install -m 755 "${INSTALL_DIR}/xnode.sh" "${BIN_PATH}"
  else
    # 兜底：直接指向 /opt/xnode/xnode
    cat > "${BIN_PATH}" <<EOF
#!/usr/bin/env bash
export XNODE_ROOT="${INSTALL_DIR}"
exec "${INSTALL_DIR}/xnode" "\$@"
EOF
    chmod +x "${BIN_PATH}"
  fi

  ok "命令已安装: xnode"
}

# --- 权限检测 ---
[[ "${EUID:-$(id -u)}" -eq 0 ]] || fail "请使用 root 运行: sudo bash install.sh"

# --- 解析本地脚本目录（管道安装时跳过，直接从 GitHub 拉取）---
SCRIPT_DIR=""
if [[ "${_IS_PIPE}" -eq 0 ]]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
  if [[ "${SCRIPT_PATH}" != /* ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
  else
    SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
  fi
fi

# --- 系统检测 ---
if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  case "${ID}-${VERSION_ID}" in
    ubuntu-20.04|ubuntu-22.04|ubuntu-24.04|debian-11|debian-12) ;;
    ubuntu-*|debian-*)
      log "检测到 ${PRETTY_NAME:-$ID}，继续安装..."
      ;;
    *)
      fail "不支持的操作系统: ${PRETTY_NAME:-unknown} (仅支持 Ubuntu 20+/22+ 与 Debian 11+/12+)"
      ;;
  esac
else
  fail "无法检测操作系统"
fi

# --- 架构检测 ---
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) fail "不支持的架构: ${ARCH} (仅 amd64 / arm64)" ;;
esac
log "系统架构: ${ARCH}"

echo -e "${GREEN}开始安装 XNode${NC}"
echo -e "仓库: ${YELLOW}${XNODE_REPO}${NC} @ ${XNODE_BRANCH}"
echo

# --- 安装依赖 ---
log "安装系统依赖..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  curl wget jq openssl ca-certificates git \
  systemd

if ! command -v yq &>/dev/null; then
  log "安装 yq..."
  wget -qO /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" \
    && chmod +x /usr/local/bin/yq || log "yq 安装跳过"
fi

# --- 获取项目文件 ---
if [[ "${_IS_PIPE}" -eq 1 ]] || need_download_repo "${SCRIPT_DIR}"; then
  download_repo
else
  log "从本地目录安装到 ${INSTALL_DIR}..."
  mkdir -p "${INSTALL_DIR}"
  rm -rf "${INSTALL_DIR:?}"/*
  cp -a "${SCRIPT_DIR}/." "${INSTALL_DIR}/"
fi

mkdir -p "${INSTALL_DIR}/logs" "${INSTALL_DIR}/certs"
chmod +x "${INSTALL_DIR}/xnode" "${INSTALL_DIR}/install.sh" \
  "${INSTALL_DIR}/core/"*.sh "${INSTALL_DIR}/protocols/"*.sh 2>/dev/null || true

# --- 系统配置目录 ---
mkdir -p /etc/xnode/{logs,certs,inbounds}
mkdir -p /etc/sing-box

[[ -f /etc/xnode/config.json ]] || cp "${INSTALL_DIR}/data/config.json" /etc/xnode/config.json
[[ -f /etc/xnode/nodes.json ]]    || cp "${INSTALL_DIR}/data/nodes.json" /etc/xnode/nodes.json
[[ -f /etc/xnode/runtime.json ]]  || cp "${INSTALL_DIR}/data/runtime.json" /etc/xnode/runtime.json

# --- 安装 /usr/bin/xnode ---
install_bin_launcher

# --- 安装 sing-box / Xboard-Node ---
log "安装 sing-box 与 Xboard-Node..."
export XNODE_ROOT="${INSTALL_DIR}"
# shellcheck source=/dev/null
source "${INSTALL_DIR}/core/env.sh"
source "${INSTALL_DIR}/core/utils.sh"
source "${INSTALL_DIR}/core/singbox.sh"
source "${INSTALL_DIR}/core/xboard.sh"
source "${INSTALL_DIR}/core/tls.sh"
source "${INSTALL_DIR}/core/service.sh"

install_singbox
install_xboard_node
install_certbot 2>/dev/null || log "certbot 稍后可通过菜单安装"
create_xnode_service

jq --arg repo "${XNODE_REPO}" --arg branch "${XNODE_BRANCH}" --arg raw "${RAW_BASE}" \
  '.installed = true | .github_repo = $repo | .github_branch = $branch | .raw_base = $raw' \
  /etc/xnode/runtime.json > /tmp/rt.json && mv /tmp/rt.json /etc/xnode/runtime.json

ok "XNode 安装完成"
echo
echo -e "${GREEN}XNode 管理脚本使用方法:${NC}"
echo "------------------------------------------"
echo "xnode              显示管理菜单"
echo "xnode install      重新安装/更新组件"
echo "xnode generate     一键生成配置"
echo "xnode start        启动节点"
echo "xnode stop         停止节点"
echo "xnode restart      重启节点"
echo "xnode status       查看状态"
echo "xnode log          查看日志"
echo "xnode version      查看版本"
echo "xnode update_shell 更新管理脚本"
echo "xnode uninstall    卸载"
echo "------------------------------------------"
echo
echo -e "一行安装命令（分享给他人）:"
echo -e "${YELLOW}wget -qO- \"${RAW_BASE}/install.sh\" | tr -d '\\r' | bash${NC}"
echo

if [[ ! -f /etc/xnode/.configured ]]; then
  read -rp "检测为首次安装，是否一键生成配置？(y/n): " if_generate
  if [[ "${if_generate}" == [Yy] ]]; then
    xnode generate || true
    touch /etc/xnode/.configured
  fi
fi

# 远程 wget 到当前目录时删除 install.sh（同 V2bX）
if [[ "${_IS_PIPE}" -eq 0 && -n "${SCRIPT_DIR}" ]] && [[ "${SCRIPT_DIR}" != "${INSTALL_DIR}" ]] \
  && [[ -f "${SCRIPT_DIR}/install.sh" ]] && need_download_repo "${SCRIPT_DIR}" 2>/dev/null; then
  rm -f "${SCRIPT_DIR}/install.sh" 2>/dev/null || true
fi

echo
