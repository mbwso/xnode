#!/usr/bin/env bash
# XNode 主菜单（布局参考 V2bX-script/V2bX.sh）

# 安装环境
menu_install_env() {
  require_root
  [[ "${1:-}" != "0" ]] && show_banner
  info "开始安装环境..."
  install_singbox || return 1
  install_xboard_node || return 1
  install_certbot 2>/dev/null || warn "certbot 可稍后通过菜单安装"
  create_xnode_service
  singbox_init_base_config
  jq '.installed = true | .last_apply = (now | todate)' "${XNODE_RUNTIME}" \
    > "${XNODE_RUNTIME}.tmp" && mv "${XNODE_RUNTIME}.tmp" "${XNODE_RUNTIME}"
  save_listen_ip >/dev/null
  firewall_apply_all 2>/dev/null || true
  success "环境安装完成"
  [[ "${1:-}" != "0" ]] && pause
}

# 添加协议（V2bX 编号选择）
menu_add_protocol() {
  show_banner
  local domain
  domain="$(json_get "${XNODE_CONFIG}" '.domain // ""')"
  wizard_select_protocol "${domain}"
  confirm_restart
}

# 删除协议
menu_remove_protocol() {
  show_banner
  echo -e "${YELLOW}已配置协议:${PLAIN}"
  jq -r '.protocols | to_entries[] | "\(.key+1). \(.value.type) : \(.value.tag) (端口 \(.value.port))"' \
    "${XNODE_NODES}" 2>/dev/null || { echo "  (暂无)"; pause; return; }
  echo
  local idx tag
  idx="$(prompt_input "输入要删除的序号" "")"
  tag="$(jq -r --argjson i "${idx}" '.protocols[$i-1].tag // empty' "${XNODE_NODES}" 2>/dev/null)"
  [[ -z "${tag}" ]] && { error "无效序号"; pause; return; }

  rm -f "${XNODE_ETC}/inbounds/${tag}.json"
  jq --arg t "${tag}" '.protocols |= map(select(.tag != $t))' \
    "${XNODE_NODES}" > "${XNODE_NODES}.tmp" && mv "${XNODE_NODES}.tmp" "${XNODE_NODES}"

  singbox_merge_config && singbox_check_config
  confirm_restart
  success "已删除: ${tag}"
}

# Reality 密钥管理
reality_keys_menu() {
  show_banner
  echo -e "${YELLOW}Reality 密钥管理${PLAIN}"
  echo
  jq -r '.protocols[]? | select(.type=="reality") |
    "标签: \(.tag)\n  PublicKey: \(.public_key)\n  ShortID: \(.short_id)\n  SNI: \(.server_name // "N/A")\n"' \
    "${XNODE_NODES}" 2>/dev/null || echo "  (暂无 Reality 节点)"
  echo
  if confirm "是否生成新的 Reality 密钥对?" "n"; then
    gen_reality_keypair
  fi
  pause
}

# 注册协议到 nodes.json
register_protocol() {
  local meta_tmp
  meta_tmp="$(mktemp)"
  echo "$1" > "${meta_tmp}"
  jq --slurpfile meta "${meta_tmp}" '.protocols += $meta' \
    "${XNODE_NODES}" > "${XNODE_NODES}.tmp" && mv "${XNODE_NODES}.tmp" "${XNODE_NODES}"
  rm -f "${meta_tmp}"
}

# 输出客户端连接信息
print_client_info() {
  local type="$1"
  shift
  echo
  echo -e "${GREEN}=========================================${PLAIN}"
  echo -e "${GREEN} 客户端连接信息${PLAIN}"
  echo -e "${GREEN}=========================================${PLAIN}"
  case "${type}" in
    reality)
      echo "协议: VLESS Reality"
      echo "地址: $1"
      echo "端口: $2"
      echo "UUID: $3"
      echo "PublicKey: $4"
      echo "ShortID: $5"
      echo "SNI: $6"
      echo
      echo "导入链接:"
      echo "vless://$3@$1:$2?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$6&fp=chrome&pbk=$4&sid=$5&type=tcp"
      ;;
    hy2)
      echo "协议: Hysteria2"
      echo "地址: $1"
      echo "端口: $2"
      echo "密码: $3"
      [[ -n "${4:-}" ]] && echo "混淆密码: $4"
      echo
      echo "hysteria2://$3@$1:$2?sni=$1"
      ;;
    trojan)
      echo "协议: Trojan"
      echo "地址: $1 | 端口: $2 | 密码: $3"
      echo "trojan://$3@$1:$2?sni=$1"
      ;;
    tuic)
      echo "协议: TUIC"
      echo "地址: $1 | 端口: $2 | UUID: $3 | 密码: $4"
      ;;
    ss)
      echo "协议: Shadowsocks"
      echo "地址: $1 | 端口: $2 | 加密: $3 | 密码: $4"
      echo "ss://$(echo -n "${3}:$4@$1:$2" | base64 -w0 2>/dev/null || echo -n "${3}:$4@$1:$2" | base64)"
      ;;
    socks)
      echo "协议: SOCKS5 (本地)"
      echo "地址: 127.0.0.1 | 端口: $1 | 用户: $2 | 密码: $3"
      ;;
    anytls)
      echo "协议: AnyTLS"
      echo "地址: $1 | 端口: $2 | 密码: $3"
      ;;
  esac
  echo -e "${GREEN}=========================================${PLAIN}"
  echo
}

# V2bX 风格主菜单
show_menu() {
  show_banner
  cat <<'MENU'
 0. 修改配置文件 (高级)
————————————————
 1. 安装环境
 2. 更新/重装组件
 3. 卸载
————————————————
 4. 启动节点
 5. 停止节点
 6. 重启节点
 7. 查看状态
 8. 查看日志
————————————————
 9.  设置开机自启
 10. 取消开机自启
————————————————
 11. 一键生成配置 (推荐)
 12. 绑定 Xboard 面板
 13. 添加协议
 14. 删除协议
 15. TLS 证书管理
 16. Reality 密钥
 17. 防火墙 / 放行端口
 18. 查看版本
 19. 生成 Reality 密钥
 20. 升级管理脚本
 21. 退出
MENU
  echo
  xnode_show_status_line
  echo
  local num
  read -rp "请输入选择 [0-21]: " num

  case "${num}" in
    0)
      require_root
      ${EDITOR:-vi} "${XNODE_CONFIG}"
      warn "修改 sing-box 配置请编辑: ${SINGBOX_CONFIG}"
      confirm_restart
      ;;
    1) menu_install_env ;;
    2) require_root; menu_install_env ;;
    3) require_root; uninstall_xnode; pause ;;
    4) require_root; cli_start ;;
    5) require_root; cli_stop ;;
    6) require_root; cli_restart ;;
    7) cli_status ;;
    8) cli_log ;;
    9) require_root; cli_enable ;;
    10) require_root; cli_disable ;;
    11) require_root; wizard_generate_config; pause ;;
    12) require_root; bind_panel; confirm_restart; pause ;;
    13) require_root; menu_add_protocol; pause ;;
    14) require_root; menu_remove_protocol ;;
    15) require_root; tls_menu ;;
    16) reality_keys_menu ;;
    17) require_root; firewall_menu ;;
    18) cli_version ;;
    19) cli_x25519 ;;
    20) cli_update_shell ;;
    21) echo "再见"; exit 0 ;;
    *) warn "请输入正确数字" ; pause ;;
  esac
}

main_menu() {
  ensure_json_file "${XNODE_CONFIG}" '{"version":1,"domain":"","listen_ip":"","cert":{},"panel":{},"protocols":[]}'
  ensure_json_file "${XNODE_NODES}" '{"protocols":[]}'
  ensure_json_file "${XNODE_RUNTIME}" '{"installed":false}'

  while true; do
    show_menu
  done
}
