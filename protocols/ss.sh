#!/usr/bin/env bash
# Shadowsocks 协议

protocol_add_ss() {
  local domain="${1:-}"
  local port password method tag inbound_file choice

  domain="${domain:-$(prompt_input "节点地址 (IP 或域名)" "")}"
  local listen_ip
  listen_ip="$(get_listen_ip)"

  port="$(prompt_input "端口" "${XNODE_DEFAULT_PORTS[ss]}")"
  
  # 加密算法选择菜单
  echo "请选择加密算法:"
  echo "1. aes-128-gcm"
  echo "2. aes-192-gcm"
  echo "3. aes-256-gcm (推荐)"
  echo "4. chacha20-ietf-poly1305"
  echo "5. 2022-blake3-aes-128-gcm"
  echo "6. 2022-blake3-aes-256-gcm"
  echo "7. 2022-blake3-chacha20-poly1305"
  choice="$(prompt_input "请选择 [1-7]" "3")"
  
  case "${choice}" in
    1) method="aes-128-gcm" ;;
    2) method="aes-192-gcm" ;;
    3) method="aes-256-gcm" ;;
    4) method="chacha20-ietf-poly1305" ;;
    5) method="2022-blake3-aes-128-gcm" ;;
    6) method="2022-blake3-aes-256-gcm" ;;
    7) method="2022-blake3-chacha20-poly1305" ;;
    *) method="aes-256-gcm" ;;
  esac
  
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
