locals {
  location = "canadacentral"
  subnet_id = var.subnet_choice == 1 ? azurerm_subnet.subnet1.id : azurerm_subnet.subnet2.id

}

