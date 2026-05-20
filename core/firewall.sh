#!/usr/bin/env bash
# 防火墙管理 (ufw / iptables)

# 检测防火墙类型
firewall_detect() {
  if cmd_exists ufw && ufw status 2>/dev/null | grep -q "Status:"; then
    echo "ufw"
  elif cmd_exists iptables; then
    echo "iptables"
  else
    echo "none"
  fi
}

# 放行端口
firewall_allow_port() {
  local port="$1"
  local proto="${2:-tcp}"
  local fw
  fw="$(firewall_detect)"

  case "${fw}" in
    ufw)
      ufw allow "${port}/${proto}" comment "xnode" >/dev/null 2>&1
      ;;
    iptables)
      if [[ "${proto}" == "udp" ]]; then
        iptables -C INPUT -p udp --dport "${port}" -j ACCEPT 2>/dev/null \
          || iptables -A INPUT -p udp --dport "${port}" -j ACCEPT
      else
        iptables -C INPUT -p tcp --dport "${port}" -j ACCEPT 2>/dev/null \
          || iptables -A INPUT -p tcp --dport "${port}" -j ACCEPT
      fi
      ;;
    none)
      warn "未检测到防火墙，跳过端口 ${port}/${proto}"
      ;;
  esac
}

# 根据协议类型放行
firewall_allow_protocol() {
  local type="$1"
  local port="$2"

  case "${type}" in
    reality|trojan|ss|socks|anytls)
      firewall_allow_port "${port}" tcp
      ;;
    hy2|tuic)
      firewall_allow_port "${port}" udp
      firewall_allow_port "${port}" tcp
      ;;
    *)
      firewall_allow_port "${port}" tcp
      ;;
  esac
}

# 放行所有已配置协议端口
firewall_apply_all() {
  info "正在放行已配置协议端口..."
  jq -r '.protocols[]? | "\(.type) \(.port)"' "${XNODE_NODES}" 2>/dev/null \
    | while read -r ptype pport; do
        firewall_allow_protocol "${ptype}" "${pport}"
      done
  success "防火墙规则已应用"
}

# 放行全部端口（V2bX 菜单项 16 open_ports 简化版）
firewall_open_all_ports() {
  local fw
  fw="$(firewall_detect)"
  case "${fw}" in
    ufw)
      ufw --force enable
      ufw default allow incoming
      success "ufw 已放行所有入站"
      ;;
    iptables)
      iptables -P INPUT ACCEPT 2>/dev/null || true
      success "iptables INPUT 已设为 ACCEPT"
      ;;
    *)
      warn "未检测到防火墙"
      ;;
  esac
}

# 防火墙管理菜单
firewall_menu() {
  show_banner
  echo -e "${YELLOW}防火墙类型: $(firewall_detect)${PLAIN}"
  echo
  menu_select "请选择" \
    "放行所有已配置端口" \
    "放行 VPS 全部端口 (同 V2bX)" \
    "手动放行 TCP 端口" \
    "手动放行 UDP 端口" || return

  case "${REPLY}" in
    0) firewall_apply_all ;;
    1) firewall_open_all_ports ;;
    2)
      local p
      p="$(prompt_input "TCP 端口" "")"
      firewall_allow_port "${p}" tcp
      ;;
    3)
      local p
      p="$(prompt_input "UDP 端口" "")"
      firewall_allow_port "${p}" udp
      ;;
  esac
  pause
}
