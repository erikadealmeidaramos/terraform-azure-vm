terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "rg-dever-de-casa-infra" {
  name     = "rg-dever-de-casa-infra"
  location = "East US"

  tags = {
    environment = "Development"
    faculdade   = "impacta"
    turma       = "fs05"
  }
}

resource "azurerm_virtual_network" "vnet-dever-de-casa-infra" {
  name                = "vnet-dever-de-casa-infra"
  location            = azurerm_resource_group.rg-dever-de-casa-infra.location
  resource_group_name = azurerm_resource_group.rg-dever-de-casa-infra.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Development"
    faculdade   = "impacta"
    turma       = "fs05"
  }
}

resource "azurerm_subnet" "sub-dever-de-casa-infra" {
  name                 = "sub-dever-de-casa-infra"
  resource_group_name  = azurerm_resource_group.rg-dever-de-casa-infra.name
  virtual_network_name = azurerm_virtual_network.vnet-dever-de-casa-infra.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_network_security_group" "nsg-dever-de-casa-infra" {
  name                = "nsg-dever-de-casa-infra"
  location            = azurerm_resource_group.rg-dever-de-casa-infra.location
  resource_group_name = azurerm_resource_group.rg-dever-de-casa-infra.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Development"
    faculdade   = "impacta"
    turma       = "fs05"
  }
}

resource "azurerm_public_ip" "ip-dever-de-casa-infra" {
  name                = "ip-dever-de-casa-infra"
  resource_group_name = azurerm_resource_group.rg-dever-de-casa-infra.name
  location            = azurerm_resource_group.rg-dever-de-casa-infra.location
  allocation_method   = "Static"

  tags = {
    environment = "Development"
    faculdade   = "impacta"
    turma       = "fs05"
  }
}

resource "azurerm_network_interface" "nic-dever-de-casa-infra" {
  name                = "nic-dever-de-casa-infra"
  location            = azurerm_resource_group.rg-dever-de-casa-infra.location
  resource_group_name = azurerm_resource_group.rg-dever-de-casa-infra.name

  ip_configuration {
    name                          = "nic-internal"
    subnet_id                     = azurerm_subnet.sub-dever-de-casa-infra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-dever-de-casa-infra.id
  }
}

resource "azurerm_virtual_machine" "vm-dever-de-casa-infra" {
  name                  = "vm-dever-de-casa-infra"
  location              = azurerm_resource_group.rg-dever-de-casa-infra.location
  resource_group_name   = azurerm_resource_group.rg-dever-de-casa-infra.name
  network_interface_ids = [azurerm_network_interface.nic-dever-de-casa-infra.id]
  vm_size               = "Standard_DS1_v2"


  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = var.user
    admin_password = var.pwd_user
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "Development"
    faculdade   = "impacta"
    turma       = "fs05"
  }
}

resource "null_resource" "install-apache" {
  connection {
    type     = "ssh"
    host     = azurerm_public_ip.ip-dever-de-casa-infra.ip_address
    user     = var.user
    password = var.pwd_user
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-dever-de-casa-infra
  ]
}
