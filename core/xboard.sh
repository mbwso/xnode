#!/usr/bin/env bash
# Xboard-Node 安装与面板绑定

# 安装 Xboard-Node（从 GitHub Release 直接下载）
install_xboard_node() {
  if cmd_exists xboard-node; then
    info "Xboard-Node 已安装"
    return 0
  fi

  info "正在安装 Xboard-Node..."

  # 从 GitHub 下载最新 release
  local arch url
  arch="$(detect_arch)"
  
  # 获取最新版本号
  local version
  version="$(curl -fsSL "https://api.github.com/repos/cedar2025/Xboard-Node/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null)"
  [[ -z "${version}" || "${version}" == "null" ]] && {
    error "无法获取 Xboard-Node 版本信息"
    return 1
  }

  # 构建下载URL（直接下载二进制文件）
  url="https://github.com/cedar2025/Xboard-Node/releases/download/${version}/xboard-node-linux-${arch}"

  if ! curl -fsSL "${url}" -o "${XBOARD_NODE_BIN}" 2>/dev/null; then
    error "Xboard-Node 下载失败，请检查网络或手动安装"
    rm -f "${XBOARD_NODE_BIN}"
    return 1
  fi

  chmod +x "${XBOARD_NODE_BIN}"

  if ! cmd_exists xboard-node; then
    error "Xboard-Node 安装失败"
    rm -f "${XBOARD_NODE_BIN}"
    return 1
  fi

  systemctl enable xboard-node 2>/dev/null || true
  success "Xboard-Node 已安装"
  json_set "${XNODE_RUNTIME}" '.xboard_version = "installed"'
  return 0
}

# 绑定 Xboard 面板
bind_panel() {
  local panel_url token mode kernel mode_choice
  panel_url="$(prompt_input "面板地址 (如 https://panel.example.com)" "")"
  token="$(prompt_input "通讯密钥 (Token)" "")"
  
  if [[ -z "${panel_url}" || -z "${token}" ]]; then
    error "面板地址和密钥不能为空"
    return 1
  fi

  # 规范化 URL
  panel_url="${panel_url%/}"

  # 选择绑定模式（数字选择）
  echo "请选择绑定模式:"
  echo "1. Machine 模式 (一台机器绑定多个节点)"
  echo "2. Node 模式 (一台机器对应一个节点)"
  mode_choice="$(prompt_input "请选择 [1-2]" "2")"

  case "${mode_choice}" in
    1)
      mode="machine"
      local machine_id
      machine_id="$(prompt_input "Machine ID" "1")"
      ;;
    2)
      mode="node"
      local node_id
      node_id="$(prompt_input "Node ID" "1")"
      ;;
    *)
      mode="node"
      node_id="$(prompt_input "Node ID" "1")"
      ;;
  esac

  kernel="singbox"

  info "正在绑定面板 (${mode} 模式)..."

  if [[ "${mode}" == "machine" ]]; then
    xbctl bind add-machine \
      --panel-url "${panel_url}" \
      --token "${token}" \
      --machine-id "${machine_id}" \
      --kernel "${kernel}" 2>/dev/null || true
  else
    xbctl bind add-node \
      --panel-url "${panel_url}" \
      --token "${token}" \
      --node-id "${node_id}" \
      --kernel "${kernel}" 2>/dev/null || true
  fi

  # 保存绑定信息到 config
  if [[ "${mode}" == "machine" ]]; then
    jq --arg url "${panel_url}" \
       --arg token "${token}" \
       --arg mid "${machine_id}" \
       --arg mode "${mode}" \
      '.panel = {url: $url, token: $token, machine_id: $mid, mode: $mode}' \
      "${XNODE_CONFIG}" > "${XNODE_CONFIG}.tmp" && mv "${XNODE_CONFIG}.tmp" "${XNODE_CONFIG}"
  else
    jq --arg url "${panel_url}" \
       --arg token "${token}" \
       --arg nid "${node_id}" \
       --arg mode "${mode}" \
      '.panel = {url: $url, token: $token, node_id: $nid, mode: $mode}' \
      "${XNODE_CONFIG}" > "${XNODE_CONFIG}.tmp" && mv "${XNODE_CONFIG}.tmp" "${XNODE_CONFIG}"
  fi

  success "面板绑定成功"
  systemctl restart xboard-node 2>/dev/null || true
  return 0
}

# 查看节点状态
show_node_status() {
  echo
  info "=== Xboard-Node 状态 ==="
  if cmd_exists xbctl; then
    xbctl status 2>/dev/null || xbctl service status 2>/dev/null || warn "无法获取 xbctl 状态"
  else
    warn "xbctl 未安装"
  fi

  echo
  info "=== sing-box 状态 ==="
  systemctl status sing-box --no-pager -l 2>/dev/null | head -15 || warn "sing-box 服务未运行"

  echo
  info "=== 已配置协议 ==="
  jq -r '.protocols[]? | "\(.type) | 端口:\(.port) | 标签:\(.tag)"' "${XNODE_NODES}" 2>/dev/null \
    || echo "  (暂无)"
  echo
}
