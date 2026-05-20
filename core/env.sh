#!/usr/bin/env bash
# XNode 环境变量与路径定义

# shellcheck disable=SC2034

# 安装目录（开发时使用脚本所在目录）
if [[ -d /opt/xnode ]]; then
  XNODE_ROOT="/opt/xnode"
elif [[ -d /opt/xnode-cn ]]; then
  XNODE_ROOT="/opt/xnode-cn"
else
  XNODE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# 系统配置目录
XNODE_ETC="/etc/xnode"
XNODE_CONFIG="${XNODE_ETC}/config.json"
XNODE_NODES="${XNODE_ETC}/nodes.json"
XNODE_RUNTIME="${XNODE_ETC}/runtime.json"
XNODE_LOG_DIR="${XNODE_ETC}/logs"
XNODE_CERT_DIR="${XNODE_ETC}/certs"

# 开发模式回退到项目 data 目录
if [[ ! -f "${XNODE_CONFIG}" ]]; then
  XNODE_ETC="${XNODE_ROOT}/data"
  XNODE_CONFIG="${XNODE_ETC}/config.json"
  XNODE_NODES="${XNODE_ETC}/nodes.json"
  XNODE_RUNTIME="${XNODE_ETC}/runtime.json"
  XNODE_LOG_DIR="${XNODE_ROOT}/logs"
  XNODE_CERT_DIR="${XNODE_ROOT}/certs"
fi

XNODE_CORE="${XNODE_ROOT}/core"
XNODE_PROTOCOLS="${XNODE_ROOT}/protocols"
XNODE_TEMPLATES="${XNODE_ROOT}/templates"

# sing-box / Xboard-Node 路径
SINGBOX_BIN="/usr/local/bin/sing-box"
SINGBOX_CONFIG="/etc/sing-box/config.json"
SINGBOX_SERVICE="sing-box"

XBCTL_BIN="/usr/local/bin/xbctl"
XBOARD_NODE_BIN="/usr/local/bin/xboard-node"
XBOARD_NODE_SERVICE="xboard-node"

XNODE_SERVICE="xnode"

# GitHub 发布地址
SINGBOX_REPO="https://github.com/SagerNet/sing-box/releases"
XBOARD_NODE_REPO="https://github.com/cedar2025/xboard-node/releases"

# 一行安装源（install.sh 会写入 runtime.json）
XNODE_REPO="${XNODE_REPO:-mbwso/xnode}"
XNODE_BRANCH="${XNODE_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${XNODE_REPO}/${XNODE_BRANCH}"

# 协议默认端口
declare -gA XNODE_DEFAULT_PORTS=(
  [reality]=443
  [hy2]=2053
  [tuic]=2096
  [trojan]=8443
  [ss]=8388
  [socks]=1080
  [anytls]=9443
)

# 协议中文名
declare -gA XNODE_PROTOCOL_NAMES=(
  [reality]="VLESS Reality"
  [hy2]="Hysteria2"
  [tuic]="TUIC"
  [trojan]="Trojan"
  [ss]="Shadowsocks"
  [socks]="SOCKS5"
  [anytls]="AnyTLS"
)
