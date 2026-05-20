#!/usr/bin/env bash
# sing-box 安装与配置合并

# 获取最新 sing-box 版本号（只取一行，避免 URL 畸形）
singbox_latest_version() {
  local ver
  ver="$(curl -fsSL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" 2>/dev/null \
    | jq -r '.tag_name // empty' | sed 's/^v//')"
  if [[ -z "${ver}" ]]; then
    ver="$(curl -fsSLI "${SINGBOX_REPO}/latest" 2>/dev/null \
      | awk -F'/tag/v' '/^location:/I {print $2; exit}' | tr -d '\r\n')"
    ver="${ver%%/*}"
  fi
  # 只保留 x.y.z
  echo "${ver}" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# 安装 sing-box
install_singbox() {
  local arch version url tmpdir
  arch="$(detect_arch)"
  if [[ "${arch}" == "unsupported" ]]; then
    error "不支持的架构: $(uname -m)"
    return 1
  fi

  version="$(singbox_latest_version)"
  version="${version//$'\n'/}"
  version="${version//$'\r'/}"
  version="$(printf '%s' "${version}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -z "${version}" ]] && { error "无法获取 sing-box 版本号"; return 1; }
  info "正在安装 sing-box v${version} (${arch})..."

  tmpdir="$(mktemp -d)"
  url="${SINGBOX_REPO}/download/v${version}/sing-box-${version}-linux-${arch}.tar.gz"
  curl -fsSL "${url}" -o "${tmpdir}/sing-box.tar.gz" || {
    error "下载 sing-box 失败"
    rm -rf "${tmpdir}"
    return 1
  }

  tar -xzf "${tmpdir}/sing-box.tar.gz" -C "${tmpdir}"
  install -m 755 "${tmpdir}/sing-box-${version}-linux-${arch}/sing-box" "${SINGBOX_BIN}"
  rm -rf "${tmpdir}"

  mkdir -p /etc/sing-box
  success "sing-box 已安装: $(${SINGBOX_BIN} version 2>/dev/null | head -1)"

  # 创建 systemd 服务（若不存在）
  if [[ ! -f /etc/systemd/system/sing-box.service ]]; then
    cat > /etc/systemd/system/sing-box.service <<'EOF'
[Unit]
Description=sing-box service
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable sing-box
  fi

  json_set "${XNODE_RUNTIME}" '.singbox_version = "'"${version}"'"'
  return 0
}

# 生成 Reality 密钥对
gen_reality_keypair() {
  if cmd_exists sing-box; then
    sing-box generate reality-keypair 2>/dev/null
    return
  fi
  error "需要 sing-box 来生成 Reality 密钥"
  return 1
}

# 初始化基础配置（DNS/route/experimental，参考 V2bX sing_origin.json）
singbox_init_base_config() {
  local base_tpl="${XNODE_TEMPLATES}/base.json"
  local dns_strategy="ipv4_only"
  [[ "$(check_ipv6_support)" == "1" ]] && dns_strategy="prefer_ipv4"

  jq --arg strategy "${dns_strategy}" \
    '.dns.strategy = $strategy | .outbounds[0].domain_resolver.strategy = $strategy' \
    "${base_tpl}" > "${XNODE_ETC}/base.generated.json" 2>/dev/null \
    || cp "${base_tpl}" "${XNODE_ETC}/base.generated.json"

  mkdir -p "$(dirname "${SINGBOX_CONFIG}")"
  cp "${XNODE_ETC}/base.generated.json" "${SINGBOX_CONFIG}"
}

# 从 nodes.json 合并生成 sing-box 配置
singbox_merge_config() {
  local base_tpl="${XNODE_ETC}/base.generated.json"
  [[ ! -f "${base_tpl}" ]] && base_tpl="${XNODE_TEMPLATES}/base.json"
  local tmp

  if [[ ! -f "${XNODE_NODES}" ]]; then
    error "节点数据不存在: ${XNODE_NODES}"
    return 1
  fi

  tmp="$(mktemp)"
  cp "${base_tpl}" "${tmp}"

  # 遍历已保存的 inbound JSON，用 jq merge（禁止字符串拼接）
  while IFS= read -r inbound_path; do
    [[ -f "${inbound_path}" ]] || continue
    jq --slurpfile ib "${inbound_path}" \
      '.inbounds += [$ib[0]]' "${tmp}" > "${tmp}.new" && mv "${tmp}.new" "${tmp}"
  done < <(jq -r '.protocols[]?.inbound_file // empty' "${XNODE_NODES}" 2>/dev/null)

  mkdir -p "$(dirname "${SINGBOX_CONFIG}")" "$(dirname "${XNODE_CONFIG}")"
  cp "${tmp}" "${SINGBOX_CONFIG}"
  cp "${tmp}" "${XNODE_CONFIG}"
  rm -f "${tmp}"

  success "配置已生成: ${SINGBOX_CONFIG}"
  return 0
}

# 保存单个 inbound 片段
singbox_save_inbound() {
  local tag="$1"
  local inbound_json="$2"
  local dir="${XNODE_ETC}/inbounds"
  local file="${dir}/${tag}.json"
  mkdir -p "${dir}"
  echo "${inbound_json}" | jq '.' > "${file}"
  echo "${file}"
}

# 校验配置
singbox_check_config() {
  if cmd_exists sing-box; then
    sing-box check -c "${SINGBOX_CONFIG}" 2>&1
    return $?
  fi
  jq empty "${SINGBOX_CONFIG}" 2>/dev/null
}

# 重启 sing-box
singbox_restart() {
  if systemctl is-active --quiet sing-box 2>/dev/null; then
    systemctl restart sing-box
  else
    systemctl start sing-box 2>/dev/null || true
  fi
}
