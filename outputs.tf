output "vpn_resource" {
  value = azurerm_resource_group.vpn_resource.name
}
output "vpn_public_ip" {
  value = azurerm_public_ip.vpn_public.ip_address
  description = "The public IP address of the VPN server"
}