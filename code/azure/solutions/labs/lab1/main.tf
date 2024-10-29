provider "azurerm" {
  features {}
}

terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "0.7.2"  # Make sure to use the version that match latest version
    }
  }
}

variable "location" {
  default = "East US"
}
variable "myname" {
  default = "ofer"
}

variable "vm_size" {
  default = "Standard_B1ms"
}

variable "admin_username" {
  default = "adminuser-[YOURNAME]"
}

variable "admin_password" {
  default = "Password123!"
}

resource "time_sleep" "wait_for_ip" {
  create_duration = "30s"  # Wait for 30 seconds
}


resource "azurerm_resource_group" "rg-ofer" {
  name     = "${var.myname}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "vnet-ofer" {
  name                = "${var.myname}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-ofer.name
}

resource "azurerm_subnet" "subnet-ofer" {
  name                 = "${var.myname}-subnet"
  resource_group_name  = azurerm_resource_group.rg-ofer.name
  virtual_network_name = azurerm_virtual_network.vnet-ofer.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip-ofer" {
  name                = "${var.myname}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-ofer.name
  allocation_method   = "Dynamic"  # Dynamic IP allocation for Basic SKU
  sku = "Basic"  
}

# Use Basic SKU (Stock Keeping Unit - azure tiers) for dynamic IP

resource "azurerm_network_interface" "nic-ofer" {
  name                = "${var.myname}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-ofer.name

  ip_configuration {
    name                          = "${var.myname}-ipconfig"
    subnet_id                     = azurerm_subnet.subnet-ofer.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-ofer.id
  }
}

resource "azurerm_linux_virtual_machine" "vm-ofer" {
  name                  = "${var.myname}-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-ofer.name
  network_interface_ids = [azurerm_network_interface.nic-ofer.id]
  size                  = var.vm_size

  os_disk {
    name              = "${var.myname}-os-disk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_username = var.admin_username
  admin_password = var.admin_password

  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name = "${var.myname}-vm"
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip-ofer.ip_address
  depends_on  = [time_sleep.wait_for_ip]  # Wait for the time_sleep resource to complete
  description = "Public IP address of the VM"
}


