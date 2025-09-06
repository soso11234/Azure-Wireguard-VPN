#!/usr/bin/env bash
set -euo pipefail
<<<<<<< HEAD

WG_IF="wg0"
SUBNET_PREFIX="10.8.0"
DNS_IP="1.1.1.1"
ENDPOINT_IP="4.204.66.179"
WG_PORT="51820"
VAULT_NAME="vpn-keyvault6556"
OUT_DIR="/opt/wg/out"
LOCK="/opt/wg/make.lock"
=======
source secret.env

#.env example

#WG_IF="wg0"
#SUBNET_PREFIX="10.8.0"
#DNS_IP="1.1.1.1"
#ENDPOINT_IP=<YOUR_PUBLIC_IP>
#WG_PORT=<OPEN PORT>
#VAULT_NAME=<YOUR KEYVALUT NAME>
#OUT_DIR=<OUT DIRECTORY address>
#LOCK=<LOCK ADDRESS>
>>>>>>> 82b049e (final!)

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "RUN as root: sudo $0 <name>"
  exit 1
fi
command -v wg >/dev/null 2>&1 || { echo "wireguard-tools missing"; exit 1; }
[ -f /etc/wireguard/${WG_IF}.conf ] || { echo "etc/wireguard/${WG_IF}.conf not found"; exit 1; }
mkdir -p "$OUT_DIR"

if command -v az >/dev/null 2>&1; then
  az account show >/dev/null 2>&1 || az login --identity >/dev/null 2>&1 || true
else
  echo "WARNING: az CLI not found" >&2
fi

next_ip() {
  local used i ip
  used=$(grep -oE "${SUBNET_PREFIX}\.[0-9]{1,3}" /etc/wireguard/${WG_IF}.conf 2>/dev/null | sort -u)
  for i in $(seq 2 254); do
    ip="${SUBNET_PREFIX}.${i}"
    echo "$used" | grep -qx "$ip" || { echo "$ip"; return; }
  done
  echo "no free ip" >&2; return 1
}

NAME="${1:-}"
[[ -n "$NAME" ]] || { echo "Usage: $0 <client_name>"; exit 2; }

(
  flock -x 200

  if grep -q "^# ${NAME}\b" /etc/wireguard/${WG_IF}.conf 2>/dev/null;then
    echo "Client '${NAME}' already exists in ${WG_IF}.conf"; exit 3
  fi

  SERVER_PUB="$(wg show ${WG_IF} public-key)"

  CLI_IP="$(next_ip)"
  CLI_PRIV="$(wg genkey)"
  CLI_PUB="$(printf "%s" "$CLI_PRIV" | wg pubkey)"

  wg set ${WG_IF} peer "$CLI_PUB" allowed-ips "${CLI_IP}/32"

 cat >> /etc/wireguard/${WG_IF}.conf <<EOF

[Peer]
# ${NAME}
PublicKey = ${CLI_PUB}
AllowedIPs = ${CLI_IP}/32
EOF

  if command -v az >/dev/null 2>&1; then
    az keyvault secret set \
      --vault-name "${VAULT_NAME}" \
      --name "client-${NAME}-publickey" \
      --value "${CLI_PUB}" >/dev/null
  fi

  CONF_PATH="${OUT_DIR}/${NAME}.conf"
  cat > "$CONF_PATH" <<EOF

[Interface]
PrivateKey = ${CLI_PRIV}
Address = ${CLI_IP}/32
DNS = ${DNS_IP}

[Peer]
Publickey = ${SERVER_PUB}
Endpoint = ${ENDPOINT_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeealive = 25
EOF

  chmod 644 "$CONF_PATH"

  if command -v qrencode >/dev/null; then
    qrencode -o "${OUT_DIR}/${NAME}.png" < "$CONF_PATH"
  fi

  echo "DONE"
  echo "CONF:${CONF_PATH}"
  if [ -f "${OUT_DIR}/${NAME}.png" ]; then
     echo "PNG: ${OUT_DIR}/${NAME}.png"
  fi
  exit 0
) 200>"$LOCK"
