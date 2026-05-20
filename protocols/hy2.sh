#!/usr/bin/env bash
# Hysteria2 协议

protocol_add_hy2() {
  local domain="${1:-}"
  local port password obfs_pass tag cert key inbound_file listen_ip cert_mode

  listen_ip="$(get_listen_ip)"
  cert_mode="${XNODE_CERT_MODE:-$(json_get "${XNODE_CONFIG}" '.cert.mode // "http"')}"
  domain="${domain:-${XNODE_CERT_DOMAIN:-$(prompt_input "域名 (需已解析到本机)" "")}}"
  [[ -z "${domain}" ]] && { error "域名必填"; return 1; }

  if ! domain_points_here "${domain}"; then
    warn "域名可能未解析到本机"
    confirm "继续?" "n" || return 1
  fi

  port="$(prompt_input "端口" "${XNODE_DEFAULT_PORTS[hy2]}")"
  password="$(gen_password 24)"
  obfs_pass="$(gen_password 16)"
  tag="hy2-${port}"

  tls_setup_for_domain "${domain}" "${cert_mode}" || return 1
  cert="$(tls_resolve_cert_paths "${domain}" "${cert_mode}" | head -1)"
  key="$(tls_resolve_cert_paths "${domain}" "${cert_mode}" | tail -1)"

  inbound_file="$(singbox_save_inbound "${tag}" "$(
    jq \
      --arg tag "${tag}" \
      --arg listen "${listen_ip}" \
      --argjson port "${port}" \
      --arg password "${password}" \
      --arg obfs_pass "${obfs_pass}" \
      --arg domain "${domain}" \
      --arg cert "${cert}" \
      --arg key "${key}" \
      '
      .tag = $tag | .listen = $listen | .listen_port = $port
      | .users[0].password = $password
      | .obfs.password = $obfs_pass
      | .tls.server_name = $domain
      | .tls.certificate_path = $cert | .tls.key_path = $key
      ' "${XNODE_TEMPLATES}/hy2.json"
  )")"

  register_protocol "$(jq -n \
    --arg type "hy2" --arg tag "${tag}" --argjson port "${port}" \
    --arg domain "${domain}" --arg password "${password}" --arg obfs_pass "${obfs_pass}" \
    --arg inbound_file "${inbound_file}" \
    '{type:$type, tag:$tag, port:$port, domain:$domain, password:$password, obfs_password:$obfs_pass, inbound_file:$inbound_file}')"

  singbox_merge_config && singbox_check_config && firewall_allow_protocol hy2 "${port}" && singbox_restart
  print_client_info hy2 "${domain}" "${port}" "${password}" "${obfs_pass}"
  success "Hysteria2 节点已添加"
}
