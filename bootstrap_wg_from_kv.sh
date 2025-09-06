#!/usr/bin/env bash
set -euo pipefail
<<<<<<< HEAD

VAULT_NAME="${VAULT_NAME:-vpn-keyvault6556}"
WG_IF="${WG_IF:-wg0}"
WG_ADDR="${WG_ADDR:-10.8.0.1/24}"
WG_PORT="${WG_PORT:-51820}"
=======
source secret.env

#example
#VAULT_NAME={YOUR KEY VAULT NAME}
#WG_IF={WG_IF}
#WG_ADDR={WG_ADDRESS}
#WG_PORT="{OPEN PORT FOR WG}"
>>>>>>> 82b049e (final!)

az login --identity --allow-no-subscriptions >/dev/null || true

sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard

NIC="$(ip route | awk '/default/ {print $5; exit}')"
[ -n "$NIC" ] || { echo "NIC NOT FOUND"; exit 1; }

SERVER_PRIV="$(az keyvault secret show --vault-name "$VAULT_NAME" --name server-privatekey --query value -o tsv 2>/dev/null || true)"
SERVER_PUB="$(az keyvault secret show --vault-name "$VAULT_NAME" --name server-publickey --query value -o tsv 2>/dev/null || true)"

if [ -z "${SERVER_PRIV}" ]; then
   umask 077
   SERVER_PRIV="$(wg genkey)"
   SERVER_PUB="$(printf "%s" "$SERVER_PRIV" | wg pubkey)"
   az keyvault secret set --vault-name "$VAULT_NAME" --name server-privatekey --value "$SERVER_PRIV" --only-show-errors >/dev/null
   az keyvault secret set --vault-name "$VAULT_NAME" --name server-publickey --value "$SERVER_PUB" --only-show-errors >/dev/null
   echo "Generated new server keypair and saved to Key Vault '$VAULT_NAME'"
fi

umask 077
printf "%s" "$SERVER_PRIV" | sudo tee /etc/wireguard/server_privatekey >/dev/null
printf "%s" "$SERVER_PUB" | sudo tee /etc/wireguard/server_publickey >/dev/null
sudo chmod 600 /etc/wireguard/server_privatekey /etc/wireguard/server_publickey

sudo bash -c "cat > /etc/wireguard/${WG_IF}.conf" <<CFG
[Interface]
Address = ${WG_ADDR}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
PostUp = iptables -t nat -A POSTROUTING -o ${NIC} -j MASQUERADE; iptables -A FORWARD -i "%i" -j ACCEPT; iptables -A FORWARD -o "%i" -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${NIC} -j MASQUERADE; iptables -D FORWARD -i "%i" -j ACCEPT; iptables -D FORWARD -o "%i" -j ACCEPT
CFG
sudo chmod 600 /etc/wireguard/${WG_IF}.conf

if ! command -v wg-quick>/dev/null;then
   echo " Wg-quick not found, sudo apt-get install -y wireguard-tools"
   exit 1
fi

sudo systemctl enable --now wg-quick@${WG_IF}
echo "Wireguard up NIC =${NIC} IF=${WG_IF} ADDR=${WG_ADDR} PORT =${WG_PORT}"
wg show




