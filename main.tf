

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = var.sub_id
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

resource "azurerm_resource_group" "vpn_resource" {
  name     = "VPN_RESOURCE"
  location = local.location
}

resource "azurerm_network_security_group" "vpn_secure" {
  name                = "vpn_secure"
  location            = azurerm_resource_group.vpn_resource.location
  resource_group_name = azurerm_resource_group.vpn_resource.name
  depends_on = [azurerm_resource_group.vpn_resource]
}

resource "azurerm_network_interface_security_group_association" "vpn_interface_nsg" {
  network_interface_id      = azurerm_network_interface.vpn_interface.id
  network_security_group_id = azurerm_network_security_group.vpn_secure.id
}

resource "azurerm_virtual_network" "vpn_VNetwork" {
  name                = "vpn_VNetwork"
  location            = azurerm_resource_group.vpn_resource.location
  resource_group_name = azurerm_resource_group.vpn_resource.name
  address_space       = ["10.0.0.0/16"]
  
  
  depends_on = [azurerm_resource_group.vpn_resource]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "vpn_subnet1"
  resource_group_name  = azurerm_resource_group.vpn_resource.name
  virtual_network_name = azurerm_virtual_network.vpn_VNetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "vpn_subnet2"
  resource_group_name  = azurerm_resource_group.vpn_resource.name
  virtual_network_name = azurerm_virtual_network.vpn_VNetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "vpn_subnet_secure" {
  name                = "vpn_subnet_secure-nsg"
  location            = azurerm_resource_group.vpn_resource.location
  resource_group_name = azurerm_resource_group.vpn_resource.name
}



resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.admin_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vpn_resource.name
  network_security_group_name = azurerm_network_security_group.vpn_secure.name
}

resource "azurerm_network_security_rule" "allow_wireguard" {
  name                        = "allow-wireguard"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "51820"
  source_address_prefix       = var.wireguard_source
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vpn_resource.name
  network_security_group_name = azurerm_network_security_group.vpn_secure.name
}

resource "azurerm_public_ip" "vpn_public" {
  name                = "vpn_public"
  resource_group_name = azurerm_resource_group.vpn_resource.name
  location            = azurerm_resource_group.vpn_resource.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "vpn_interface" {
  name                = "vpn_interface-nic"
  location            = azurerm_resource_group.vpn_resource.location
  resource_group_name = azurerm_resource_group.vpn_resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vpn_public.id
  }
}

resource "azurerm_linux_virtual_machine" "vpn-vm" {
  name                = "vpn-vm"
  resource_group_name = azurerm_resource_group.vpn_resource.name
  location            = azurerm_resource_group.vpn_resource.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  identity {type = "SystemAssigned"}
  network_interface_ids = [
    azurerm_network_interface.vpn_interface.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  disable_password_authentication = true
}


data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "vpn_key" {
  name                        = var.keyvault
  location                    = azurerm_resource_group.vpn_resource.location
  resource_group_name         = azurerm_resource_group.vpn_resource.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get", "Set", "List"
    ]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_virtual_machine.vpn-vm.identity[0].principal_id

    secret_permissions = [
      "Get", "Set", "List"
    ]
  } 
}