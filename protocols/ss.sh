#!/usr/bin/env bash
# Shadowsocks 协议

protocol_add_ss() {
  local domain="${1:-}"
  local port password method tag inbound_file

  domain="${domain:-$(prompt_input "节点地址 (IP 或域名)" "")}"
  local listen_ip
  listen_ip="$(get_listen_ip)"

  port="$(prompt_input "端口" "${XNODE_DEFAULT_PORTS[ss]}")"
  method="aes-256-gcm"
  password="$(gen_password 16)"
  tag="ss-${port}"

  inbound_file="$(singbox_save_inbound "${tag}" "$(
    jq \
      --arg tag "${tag}" \
      --arg listen "${listen_ip}" \
      --argjson port "${port}" \
      --arg password "${password}" \
      --arg method "${method}" \
      '.tag = $tag | .listen = $listen | .listen_port = $port | .method = $method | .password = $password' \
      "${XNODE_TEMPLATES}/ss.json"
  )")"

  register_protocol "$(jq -n \
    --arg type "ss" --arg tag "${tag}" --argjson port "${port}" \
    --arg domain "${domain}" --arg password "${password}" --arg method "${method}" \
    --arg inbound_file "${inbound_file}" \
    '{type:$type, tag:$tag, port:$port, domain:$domain, password:$password, method:$method, inbound_file:$inbound_file}')"

  singbox_merge_config && singbox_check_config && firewall_allow_protocol ss "${port}" && singbox_restart
  print_client_info ss "${domain}" "${port}" "${method}" "${password}"
  success "Shadowsocks 节点已添加"
}
