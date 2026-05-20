#!/usr/bin/env bash
# VLESS Reality 协议

protocol_add_reality() {
  local domain="${1:-}"
  local port server_name uuid private_key public_key short_id tag inbound_file listen_ip
  local keypair

  listen_ip="$(get_listen_ip)"
  domain="${domain:-$(prompt_input "节点域名/地址" "")}"
  port="$(prompt_input "端口" "${XNODE_DEFAULT_PORTS[reality]}")"
  server_name="$(prompt_input "Reality 伪装域名 (SNI)" "www.cloudflare.com")"

  uuid="$(gen_uuid)"
  short_id="$(gen_short_id)"

  keypair="$(gen_reality_keypair)" || return 1
  private_key="$(echo "${keypair}" | awk '/PrivateKey/ {print $2}')"
  public_key="$(echo "${keypair}" | awk '/PublicKey/ {print $2}')"

  [[ -z "${private_key}" ]] && {
    # sing-box 输出格式: PrivateKey: xxx / PublicKey: xxx
    private_key="$(echo "${keypair}" | grep -i private | awk '{print $NF}')"
    public_key="$(echo "${keypair}" | grep -i public | awk '{print $NF}')"
  }

  tag="reality-${port}"

  # 用 jq 从模板生成 inbound（禁止字符串拼 JSON）
  inbound_file="$(singbox_save_inbound "${tag}" "$(
    jq \
      --arg tag "${tag}" \
      --arg listen "${listen_ip}" \
      --argjson port "${port}" \
      --arg uuid "${uuid}" \
      --arg server_name "${server_name}" \
      --arg private_key "${private_key}" \
      --arg short_id "${short_id}" \
      '
      .tag = $tag
      | .listen = $listen
      | .listen_port = $port
      | .users[0].uuid = $uuid
      | .tls.server_name = $server_name
      | .tls.reality.handshake.server = $server_name
      | .tls.reality.private_key = $private_key
      | .tls.reality.short_id = [$short_id]
      ' "${XNODE_TEMPLATES}/reality.json"
  )")"

  register_protocol "$(jq -n \
    --arg type "reality" \
    --arg tag "${tag}" \
    --argjson port "${port}" \
    --arg domain "${domain}" \
    --arg uuid "${uuid}" \
    --arg public_key "${public_key}" \
    --arg private_key "${private_key}" \
    --arg short_id "${short_id}" \
    --arg server_name "${server_name}" \
    --arg inbound_file "${inbound_file}" \
    '{type:$type, tag:$tag, port:$port, domain:$domain, uuid:$uuid,
      public_key:$public_key, private_key:$private_key, short_id:$short_id,
      server_name:$server_name, inbound_file:$inbound_file}')"

  singbox_merge_config
  singbox_check_config || { error "配置校验失败"; return 1; }
  firewall_allow_protocol reality "${port}"
  singbox_restart

  print_client_info reality "${domain}" "${port}" "${uuid}" "${public_key}" "${short_id}" "${server_name}"
  success "Reality 节点已添加"
}
