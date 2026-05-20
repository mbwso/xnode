#!/usr/bin/env bash
# systemd 服务管理

# 创建 xnode 元服务（管理 sing-box + 配置同步）
create_xnode_service() {
  cat > /etc/systemd/system/xnode.service <<EOF
[Unit]
Description=XNode Node Manager
After=network.target sing-box.service xboard-node.service
Wants=sing-box.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecReload=/bin/systemctl restart sing-box
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable xnode
  success "xnode.service 已创建"
}

# 服务操作
xnode_service() {
  local action="$1"
  case "${action}" in
    start)
      systemctl start xboard-node sing-box xnode 2>/dev/null
      ;;
    stop)
      systemctl stop sing-box xboard-node 2>/dev/null
      ;;
    restart)
      systemctl restart sing-box 2>/dev/null
      systemctl restart xboard-node 2>/dev/null
      ;;
    status)
      systemctl status sing-box xboard-node xnode --no-pager 2>/dev/null
      ;;
  esac
}

# 日志菜单
logs_menu() {
  while true; do
    show_banner
    echo " 日志查看"
    echo
    menu_select "请选择" \
      "查看实时日志 (sing-box)" \
      "查看错误日志" \
      "查看最近 100 行" \
      "Xboard-Node 日志" || return

    case "${REPLY}" in
      0) journalctl -u sing-box -f ;;
      1) journalctl -u sing-box -p err --no-pager -n 50; pause ;;
      2) journalctl -u sing-box --no-pager -n 100; pause ;;
      3)
        if cmd_exists xbctl; then
          xbctl logs 2>/dev/null || journalctl -u xboard-node -f
        else
          journalctl -u xboard-node -f
        fi
        ;;
    esac
  done
}

# 卸载
uninstall_xnode() {
  if ! confirm "确定要卸载 XNode? (不会删除面板绑定数据)"; then
    return
  fi
  systemctl stop sing-box xnode 2>/dev/null
  systemctl disable xnode 2>/dev/null
  rm -f /etc/systemd/system/xnode.service
  rm -f /usr/local/bin/xnode
  systemctl daemon-reload
  warn "已移除 XNode 管理组件。sing-box / Xboard-Node 需手动卸载。"
}
