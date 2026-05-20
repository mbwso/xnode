#!/usr/bin/env bash
# 一键配置向导（交互逻辑参考 V2bX-script/initconfig.sh）

# V2bX 风格：选择传输协议
wizard_select_protocol() {
  local domain="${1:-}"

  echo -e "${YELLOW}请选择节点传输协议：${PLAIN}"
  echo -e "${GREEN}1.${PLAIN} Shadowsocks"
  echo -e "${GREEN}2.${PLAIN} Vless (Reality)"
  echo -e "${GREEN}3.${PLAIN} Hysteria2"
  echo -e "${GREEN}4.${PLAIN} Trojan"
  echo -e "${GREEN}5.${PLAIN} Tuic"
  echo -e "${GREEN}6.${PLAIN} SOCKS5 (本地)"
  echo -e "${GREEN}7.${PLAIN} AnyTLS"
  echo -e "${GREEN}0.${PLAIN} 完成配置"

  local choice
  read -rp "请输入: " choice

  case "${choice}" in
    0) return 1 ;;
    1)
      domain="${domain:-$(prompt_input '节点地址/域名' "$(json_get "${XNODE_CONFIG}" '.domain // ""')")}"
      protocol_add_ss "${domain}"
      ;;
    2)
      domain="${domain:-$(prompt_input '节点地址' "$(json_get "${XNODE_CONFIG}" '.domain // ""')")}"
      read -rp "请选择是否为 Reality 节点？(y/n) [y]: " is_reality
      is_reality="${is_reality:-y}"
      if [[ "${is_reality}" == "y" || "${is_reality}" == "Y" ]]; then
        protocol_add_reality "${domain}"
      else
        warn "非 Reality 的 VLESS TLS 暂未实现，请选择 Reality 或其他协议"
        return 0
      fi
      ;;
    3)
      domain="${domain:-$(prompt_input '节点证书域名' "")}"
      wizard_select_cert_mode y
      XNODE_CERT_MODE="${XNODE_CERT_MODE:-http}"
      protocol_add_hy2 "${domain}"
      ;;
    4)
      domain="${domain:-$(prompt_input '节点证书域名' "")}"
      wizard_select_cert_mode y
      protocol_add_trojan "${domain}"
      ;;
    5)
      domain="${domain:-$(prompt_input '节点证书域名' "")}"
      wizard_select_cert_mode y
      protocol_add_tuic "${domain}"
      ;;
    6) protocol_add_socks ;;
    7)
      domain="${domain:-$(prompt_input '节点证书域名' "")}"
      wizard_select_cert_mode y
      protocol_add_anytls "${domain}"
      ;;
    *)
      warn "无效选择"
      return 0
      ;;
  esac
  return 0
}

# 绑定面板（若未绑定）
wizard_bind_panel_if_needed() {
  local url token mid
  url="$(json_get "${XNODE_CONFIG}" '.panel.url // ""')"
  if [[ -n "${url}" ]]; then
    info "已绑定面板: ${url}"
    confirm "是否重新绑定面板?" "n" || return 0
  fi

  echo -e "${YELLOW}=== 绑定 Xboard 面板（machine 模式，支持多协议）===${PLAIN}"
  bind_panel
}

# 一键生成配置（对应 V2bX generate）
wizard_generate_config() {
  require_root
  show_banner

  save_listen_ip >/dev/null
  info "监听地址: $(get_listen_ip)（有 IPv6 时优先 ::）"

  # 初始化 sing-box 基础配置（含 DNS/route，参考 V2bX sing_origin.json）
  singbox_init_base_config

  wizard_bind_panel_if_needed

  local domain
  domain="$(prompt_input "请输入节点主域名（用于 TLS/Reality）" \
    "$(json_get "${XNODE_CONFIG}" '.domain // ""')")"
  [[ -n "${domain}" ]] && json_set "${XNODE_CONFIG}" ".domain = \"${domain}\""

  echo
  info "开始添加节点，输入 0 结束"
  while wizard_select_protocol "${domain}"; do
    confirm_restart
  done

  success "配置生成完成"
  singbox_merge_config
  singbox_check_config
  xnode_service restart
}

# 操作后询问重启（V2bX confirm_restart）
confirm_restart() {
  if confirm "是否重启节点" "y"; then
    xnode_service restart
    sleep 2
    xnode_check_status
    if [[ $? == 0 ]]; then
      success "重启成功"
    else
      warn "重启可能失败，请用 xnode log 查看"
    fi
  fi
}
