#!/usr/bin/env bash
# XNode CLI 子命令（参考 V2bX-script 的 xnode start/stop/log/generate）

# 0=运行中 1=未运行 2=未安装
xnode_check_status() {
  if [[ ! -f "${SINGBOX_BIN}" ]] && [[ ! -f "${XBOARD_NODE_BIN}" ]]; then
    return 2
  fi
  if systemctl is-active --quiet sing-box 2>/dev/null; then
    return 0
  fi
  if systemctl is-active --quiet xboard-node 2>/dev/null; then
    return 0
  fi
  return 1
}

xnode_show_status_line() {
  xnode_check_status
  case $? in
    0) echo -e "节点状态: ${GREEN}已运行${PLAIN}" ;;
    1) echo -e "节点状态: ${YELLOW}未运行${PLAIN}" ;;
    2) echo -e "节点状态: ${RED}未安装${PLAIN}" ;;
  esac
  if systemctl is-enabled --quiet sing-box 2>/dev/null; then
    echo -e "开机自启: ${GREEN}是${PLAIN}"
  else
    echo -e "开机自启: ${RED}否${PLAIN}"
  fi
}

xnode_check_install() {
  xnode_check_status
  if [[ $? == 2 ]]; then
    echo -e "${RED}请先安装环境（菜单 1 或 xnode install）${PLAIN}"
    [[ "${1:-}" == "0" ]] && return 1
    before_show_menu
    return 1
  fi
  return 0
}

xnode_check_uninstall() {
  xnode_check_status
  if [[ $? != 2 ]]; then
    echo -e "${RED}已安装，请勿重复安装${PLAIN}"
    [[ "${1:-}" == "0" ]] && return 1
    before_show_menu
    return 1
  fi
  return 0
}

cli_start() {
  xnode_check_install 0 || return 1
  xnode_check_status
  if [[ $? == 0 ]]; then
    echo -e "${GREEN}节点已在运行，如需重启请选择重启${PLAIN}"
  else
    xnode_service start
    sleep 2
    xnode_check_status
    if [[ $? == 0 ]]; then
      success "启动成功，使用 xnode log 查看日志"
    else
      error "可能启动失败，请使用 xnode log 查看"
    fi
  fi
  [[ $# == 0 ]] && before_show_menu
}

cli_stop() {
  xnode_check_install 0 || return 1
  xnode_service stop
  sleep 1
  success "已停止"
  [[ $# == 0 ]] && before_show_menu
}

cli_restart() {
  xnode_check_install 0 || return 1
  xnode_service restart
  sleep 2
  xnode_check_status
  if [[ $? == 0 ]]; then
    success "重启成功"
  else
    error "可能重启失败，请使用 xnode log 查看"
  fi
  [[ $# == 0 ]] && before_show_menu
}

cli_status() {
  xnode_check_install 0 || return 1
  show_node_status
  [[ $# == 0 ]] && before_show_menu
}

cli_log() {
  xnode_check_install 0 || return 1
  journalctl -u sing-box -u xboard-node -e --no-pager -f
}

cli_enable() {
  xnode_check_install 0 || return 1
  systemctl enable sing-box xboard-node xnode 2>/dev/null
  success "已设置开机自启"
  [[ $# == 0 ]] && before_show_menu
}

cli_disable() {
  xnode_check_install 0 || return 1
  systemctl disable sing-box xboard-node 2>/dev/null
  success "已取消开机自启"
  [[ $# == 0 ]] && before_show_menu
}

cli_version() {
  echo -n "sing-box: "
  "${SINGBOX_BIN}" version 2>/dev/null | head -1 || echo "未安装"
  echo -n "Xboard-Node: "
  xbctl version 2>/dev/null || echo "未安装"
  [[ $# == 0 ]] && before_show_menu
}

cli_x25519() {
  xnode_check_install 0 || return 1
  if cmd_exists sing-box; then
    sing-box generate reality-keypair
  else
    error "sing-box 未安装"
  fi
  [[ $# == 0 ]] && before_show_menu
}

cli_install() {
  xnode_check_uninstall 0 || return 1
  menu_install_env 0
}

cli_uninstall() {
  xnode_check_install 0 || return 1
  uninstall_xnode
  [[ $# == 0 ]] && before_show_menu
}

cli_generate() {
  require_root
  wizard_generate_config
  [[ $# == 0 ]] && before_show_menu
}

# 更新管理脚本（同 V2bX update_shell）
cli_update_shell() {
  local repo branch raw_base
  repo="$(json_get "${XNODE_RUNTIME}" '.github_repo // ""' 2>/dev/null || true)"
  branch="$(json_get "${XNODE_RUNTIME}" '.github_branch // "main"' 2>/dev/null || true)"
  [[ -z "${repo}" ]] && repo="${XNODE_REPO:-mbwso/xnode}"
  [[ -z "${branch}" ]] && branch="${XNODE_BRANCH:-main}"
  raw_base="https://raw.githubusercontent.com/${repo}/${branch}"

  if [[ "${repo}" == *"YOUR_USERNAME"* ]]; then
    error "请先在 /etc/xnode/runtime.json 设置 github_repo，或修改 install.sh 中的 XNODE_REPO"
    return 1
  fi

  if curl -fsSL "${raw_base}/xnode.sh" -o /usr/bin/xnode; then
    chmod +x /usr/bin/xnode
    success "管理脚本已更新"
  else
    error "下载失败: ${raw_base}/xnode.sh"
    return 1
  fi
  [[ $# == 0 ]] && before_show_menu
}

cli_show_usage() {
  local raw="${RAW_BASE:-https://raw.githubusercontent.com/mbwso/xnode/main}"
  cat <<EOF
XNode 管理脚本（交互参考 V2bX）

一行安装:
  wget -qO- "${raw}/install.sh" | tr -d '\r' | bash

xnode              显示管理菜单
xnode install      安装/更新环境
xnode generate     一键生成配置（向导）
xnode start        启动节点
xnode stop         停止节点
xnode restart      重启节点
xnode status       查看状态
xnode log          查看日志
xnode enable       开机自启
xnode disable      取消自启
xnode x25519       生成 Reality 密钥
xnode version      查看版本
xnode update_shell 更新本管理脚本
xnode uninstall    卸载管理组件
EOF
}

# 子命令分发
xnode_cli_dispatch() {
  case "${1:-}" in
    start)    cli_start 0 ;;
    stop)     cli_stop 0 ;;
    restart)  cli_restart 0 ;;
    status)   cli_status 0 ;;
    log|logs) cli_log 0 ;;
    enable)   cli_enable 0 ;;
    disable)  cli_disable 0 ;;
    install)  cli_install 0 ;;
    uninstall) cli_uninstall 0 ;;
    generate) cli_generate 0 ;;
    version)  cli_version 0 ;;
    x25519)   cli_x25519 0 ;;
    update_shell) cli_update_shell 0 ;;
    help|-h|--help) cli_show_usage ;;
    "")       return 1 ;;
    *)        echo -e "${RED}未知命令: $1${PLAIN}"; cli_show_usage; return 1 ;;
  esac
}
