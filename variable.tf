variable "subnet_choice" {
  description = "Choose which subnet to use (1 or 2)"
  type        = number
  default     = 1
}

variable "subscription_id"
{
  type = string
}

variable "public_key"
{
  type = string
}

variable "admin_ip"
{
  type = string
  default = "0.0.0.0/0"
}

variable "wireguard_source"
{
  type = string
  default = "0.0.0.0/0"
}

variable "vpn-key_vault"
{
  type = string
}