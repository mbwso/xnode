#!/usr/bin/env bash
# SOCKS5 协议

protocol_add_socks() {
  local port username password tag inbound_file

  port="$(prompt_input "端口" "${XNODE_DEFAULT_PORTS[socks]}")"
  username="$(prompt_input "用户名" "xnode")"
  password="$(gen_password 12)"
  tag="socks-${port}"

  inbound_file="$(singbox_save_inbound "${tag}" "$(
    jq \
      --arg tag "${tag}" \
      --argjson port "${port}" \
      --arg username "${username}" \
      --arg password "${password}" \
      '
      .tag = $tag | .listen_port = $port
      | .users[0].username = $username | .users[0].password = $password
      ' "${XNODE_TEMPLATES}/socks.json"
  )")"

  register_protocol "$(jq -n \
    --arg type "socks" --arg tag "${tag}" --argjson port "${port}" \
    --arg username "${username}" --arg password "${password}" \
    --arg inbound_file "${inbound_file}" \
    '{type:$type, tag:$tag, port:$port, username:$username, password:$password, inbound_file:$inbound_file}')"

  singbox_merge_config && singbox_check_config && firewall_allow_protocol socks "${port}" && singbox_restart
  print_client_info socks "${port}" "${username}" "${password}"
  success "SOCKS5 已添加 (默认仅监听 127.0.0.1)"
}
