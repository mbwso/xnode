#!/usr/bin/env bash
if grep -q $'\r' "$0" 2>/dev/null; then sed -i 's/\r$//' "$0" 2>/dev/null && exec bash "$0" "$@"; fi
# XNode 管理脚本入口（安装到 /usr/bin/xnode，用法同 V2bX / v2bx）
# 实际逻辑在 /opt/xnode/xnode

XNODE_ROOT="${XNODE_ROOT:-/opt/xnode}"
export XNODE_ROOT

if [[ ! -x "${XNODE_ROOT}/xnode" ]]; then
  echo "错误: 未找到 ${XNODE_ROOT}/xnode，请先运行安装脚本:"
  echo "  wget -N \"\${RAW_URL}/install.sh\" && bash install.sh"
  exit 1
fi

exec "${XNODE_ROOT}/xnode" "$@"
