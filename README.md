# Azure WireGuard VPN with Terraform + Key Vault + Telegram Bot

This project provisions a secure WireGuard VPN server on Azure, with automated key management and client provisioning.

## 🚀 Features
- **Infrastructure as Code**: Terraform configures Resource Group, VNet, Subnets, NSGs, Public IP, and Linux VM.
- **Secure Key Management**: Server keys are stored in **Azure Key Vault**. If no keys exist, they are auto-generated and saved.
- **WireGuard Auto-Setup**: `bootstrap_wg_from_kv.sh` initializes the VPN server and brings up `wg0` with proper firewall rules.
- **Client Provisioning**: 
  - `make_client.sh` generates client configs, updates server peers, and uploads public keys to Key Vault.
  - Client `.conf` files and QR codes are auto-created.
- **Telegram Bot Integration**: 
  - `wg_bot.py` allows authorized users to request new clients via `/newclient <name>`.
  - The bot sends `.conf` files and QR codes directly in chat.

## 📂 Project Structure
├── main.tf # Terraform infra (Resource Group, VM, Networking, Key Vault)
├── locals.tf # Location and local variables
├── variable.tf # Variable definitions (sub_id, keyvault, admin_ip, etc.)
├── outputs.tf # Useful outputs (VM IP, Key Vault name, etc.)
├── bootstrap_wg_from_kv.sh # Server setup script (WireGuard + Key Vault integration)
├── make_client.sh # Client provisioning script (keys, conf, QR)
├── wg_bot.py # Telegram bot for client creation
└── .gitignore # Ensures secret files are not pushed
