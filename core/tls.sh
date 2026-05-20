#!/usr/bin/env bash
# TLS 证书管理 (Let's Encrypt / certbot)

TLS_CERT_BASE="/etc/letsencrypt/live"

# 安装 certbot
install_certbot() {
  if cmd_exists certbot; then
    return 0
  fi
  info "正在安装 certbot..."
  local os
  os="$(detect_os)"
  case "${os}" in
    ubuntu-*|debian-*)
      apt-get update -qq
      apt-get install -y -qq certbot
      ;;
    *)
      warn "请手动安装 certbot"
      return 1
      ;;
  esac
  success "certbot 已安装"
}

# V2bX 风格：选择证书申请模式
# 返回: certmode (http|dns|self|none) 写入全局 XNODE_CERT_MODE
wizard_select_cert_mode() {
  local need_tls="${1:-y}"
  XNODE_CERT_MODE="none"
  XNODE_CERT_DOMAIN=""

  if [[ "${need_tls}" != "y" && "${need_tls}" != "Y" ]]; then
    return 0
  fi

  echo -e "${YELLOW}请选择证书申请模式：${PLAIN}"
  echo -e "${GREEN}1.${PLAIN} http 模式自动申请（域名已解析到本机）"
  echo -e "${GREEN}2.${PLAIN} dns 模式（需自行配置 API，稍后手动改配置）"
  echo -e "${GREEN}3.${PLAIN} self 模式（自签或已有证书文件）"
  local mode_choice
  read -rp "请输入: " mode_choice
  case "${mode_choice}" in
    1) XNODE_CERT_MODE="http" ;;
    2) XNODE_CERT_MODE="dns" ;;
    3) XNODE_CERT_MODE="self" ;;
    *) XNODE_CERT_MODE="http" ;;
  esac

  XNODE_CERT_DOMAIN="$(prompt_input "请输入节点证书域名" "$(json_get "${XNODE_CONFIG}" '.domain // ""')")"
  jq --arg mode "${XNODE_CERT_MODE}" --arg domain "${XNODE_CERT_DOMAIN}" \
    '.cert = {mode: $mode, domain: $domain}' "${XNODE_CONFIG}" \
    > "${XNODE_CONFIG}.tmp" && mv "${XNODE_CONFIG}.tmp" "${XNODE_CONFIG}"

  if [[ "${XNODE_CERT_MODE}" != "http" ]]; then
    warn "非 http 模式请稍后手动配置证书路径并重启节点"
  fi
}

# 按模式申请/准备证书
tls_setup_for_domain() {
  local domain="$1"
  local mode="${2:-http}"
  local email="${3:-}"

  case "${mode}" in
    http)
      tls_issue_cert "${domain}" "${email}"
      ;;
    dns)
      warn "dns 模式请手动运行 certbot dns 插件后，将证书路径写入配置"
      return 0
      ;;
    self)
      local cert_dir="${XNODE_CERT_DIR}/${domain}"
      mkdir -p "${cert_dir}"
      if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        info "生成自签证书..."
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
          -keyout "${cert_dir}/privkey.pem" \
          -out "${cert_dir}/fullchain.pem" \
          -subj "/CN=${domain}" 2>/dev/null
      fi
      success "自签证书目录: ${cert_dir}"
      return 0
      ;;
    none)
      return 0
      ;;
    *)
      tls_issue_cert "${domain}" "${email}"
      ;;
  esac
}

# 获取证书路径（Let's Encrypt 或自签目录）
tls_resolve_cert_paths() {
  local domain="$1"
  local mode="${2:-http}"
  if [[ "${mode}" == "self" ]]; then
    echo "${XNODE_CERT_DIR}/${domain}/fullchain.pem"
    echo "${XNODE_CERT_DIR}/${domain}/privkey.pem"
  else
    tls_cert_paths "${domain}"
  fi
}

# 申请证书
tls_issue_cert() {
  local domain="$1"
  local email="${2:-}"

  if [[ -z "${domain}" ]]; then
    error "域名不能为空"
    return 1
  fi

  if ! domain_points_here "${domain}"; then
    warn "域名 ${domain} 可能未解析到本机，继续申请可能失败"
    confirm "是否继续?" || return 1
  fi

  install_certbot || return 1

  info "正在为 ${domain} 申请证书..."
  local args=(-d "${domain}" --standalone --preferred-challenges http --agree-tos --non-interactive)
  [[ -n "${email}" ]] && args+=(--email "${email}") || args+=(--register-unsafely-without-email)

  # 临时停止占用 80 端口的服务
  systemctl stop sing-box 2>/dev/null || true

  certbot certonly "${args[@]}" || {
    error "证书申请失败"
    singbox_restart
    return 1
  }

  singbox_restart
  success "证书已签发: ${TLS_CERT_BASE}/${domain}"
  return 0
}

# 证书路径
tls_cert_paths() {
  local domain="$1"
  echo "${TLS_CERT_BASE}/${domain}/fullchain.pem"
  echo "${TLS_CERT_BASE}/${domain}/privkey.pem"
}

# 查看证书状态
tls_list_certs() {
  install_certbot 2>/dev/null || true
  if cmd_exists certbot; then
    certbot certificates 2>/dev/null
  else
    warn "certbot 未安装"
  fi
}

# 续签证书
tls_renew_certs() {
  install_certbot || return 1
  certbot renew --quiet && success "证书续签完成" || error "续签失败"
}

# 删除证书
tls_delete_cert() {
  local domain="$1"
  install_certbot || return 1
  certbot delete --cert-name "${domain}" --non-interactive 2>/dev/null \
    && success "已删除证书: ${domain}" \
    || error "删除失败"
}

# TLS 管理菜单
tls_menu() {
  while true; do
    show_banner
    echo " TLS 证书管理"
    echo
    menu_select "请选择" \
      "申请新证书" \
      "查看证书状态" \
      "续签全部证书" \
      "删除证书" || { return; }
    case "${REPLY}" in
      0)
        local domain email
        domain="$(prompt_input "域名" "$(json_get "${XNODE_CONFIG}" '.domain // ""')")"
        email="$(prompt_input "邮箱 (可选)" "")"
        tls_issue_cert "${domain}" "${email}"
        pause
        ;;
      1) tls_list_certs; pause ;;
      2) tls_renew_certs; pause ;;
      3)
        local del
        del="$(prompt_input "要删除的域名" "")"
        tls_delete_cert "${del}"
        pause
        ;;
    esac
  done
}
