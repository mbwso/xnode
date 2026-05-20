#!/usr/bin/env bash
# Trojan 协议

protocol_add_trojan() {
  local domain="${1:-}"
  local port password tag cert key inbound_file

  domain="${domain:-$(prompt_input "域名" "")}"
  [[ -z "${domain}" ]] && { error "域名必填"; return 1; }

  local listen_ip cert_mode
  listen_ip="$(get_listen_ip)"
  cert_mode="${XNODE_CERT_MODE:-$(json_get "${XNODE_CONFIG}" '.cert.mode // "http"')}"

  port="$(prompt_input "端口" "${XNODE_DEFAULT_PORTS[trojan]}")"
  password="$(gen_password 16)"
  tag="trojan-${port}"

  tls_setup_for_domain "${domain}" "${cert_mode}" || return 1
  cert="$(tls_resolve_cert_paths "${domain}" "${cert_mode}" | head -1)"
  key="$(tls_resolve_cert_paths "${domain}" "${cert_mode}" | tail -1)"

  inbound_file="$(singbox_save_inbound "${tag}" "$(
    jq \
      --arg tag "${tag}" \
      --arg listen "${listen_ip}" \
      --argjson port "${port}" \
      --arg password "${password}" \
      --arg domain "${domain}" \
      --arg cert "${cert}" \
      --arg key "${key}" \
      '
      .tag = $tag | .listen = $listen | .listen_port = $port
      | .users[0].password = $password
      | .tls.server_name = $domain
      | .tls.certificate_path = $cert | .tls.key_path = $key
      ' "${XNODE_TEMPLATES}/trojan.json"
  )")"

  register_protocol "$(jq -n \
    --arg type "trojan" --arg tag "${tag}" --argjson port "${port}" \
    --arg domain "${domain}" --arg password "${password}" --arg inbound_file "${inbound_file}" \
    '{type:$type, tag:$tag, port:$port, domain:$domain, password:$password, inbound_file:$inbound_file}')"

  singbox_merge_config && singbox_check_config && firewall_allow_protocol trojan "${port}" && singbox_restart
  print_client_info trojan "${domain}" "${port}" "${password}"
  success "Trojan 节点已添加"
}
