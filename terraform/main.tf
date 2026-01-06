# ==============================================================================
# TERRAFORM & PROVIDER CONFIGURATION
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ==============================================================================
# RESOURCE GROUP
# ==============================================================================

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
  tags     = var.tags
}

# ==============================================================================
# VIRTUAL NETWORK & SUBNET
# ==============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_subnet" "main" {
  name                 = "${var.project_name}-${var.environment}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ==============================================================================
# NETWORK SECURITY GROUP (FIREWALL RULES)
# ==============================================================================

resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-${var.environment}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  # SSH Access Rule
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_source_ips
    destination_address_prefix = "*"
  }

  # Application Port Rule (Conditional)
  dynamic "security_rule" {
    for_each = var.enable_public_app_access ? [1] : []
    content {
      name                       = "AllowAppPort"
      priority                   = 1002
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = var.application_port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # Monitoring Port Rule
  security_rule {
    name                       = "AllowMonitoring"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.monitoring_port
    source_address_prefix      = "10.0.0.0/16"  # Samo internal traffic
    destination_address_prefix = "*"
  }

  # Allow Internal Communication
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

# ==============================================================================
# PUBLIC IP ADDRESSES
# ==============================================================================

# Public IP za Application VM
resource "azurerm_public_ip" "app_vm" {
  name                = "${var.project_name}-${var.environment}-app-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Public IP za Monitoring VM
resource "azurerm_public_ip" "monitoring_vm" {
  name                = "${var.project_name}-${var.environment}-monitoring-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ==============================================================================
# NETWORK INTERFACES
# ==============================================================================

# Network Interface za Application VM
resource "azurerm_network_interface" "app_vm" {
  name                = "${var.project_name}-${var.environment}-app-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app_vm.id
  }
}

# Network Interface za Monitoring VM
resource "azurerm_network_interface" "monitoring_vm" {
  name                = "${var.project_name}-${var.environment}-monitoring-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.monitoring_vm.id
  }
}

# Associate NSG sa Network Interfaces
resource "azurerm_network_interface_security_group_association" "app_vm" {
  network_interface_id      = azurerm_network_interface.app_vm.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface_security_group_association" "monitoring_vm" {
  network_interface_id      = azurerm_network_interface.monitoring_vm.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ==============================================================================
# VIRTUAL MACHINES
# ==============================================================================

# APPLICATION VM - Za Java Dummy Service
resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "${var.project_name}-${var.environment}-app-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = merge(var.tags, { Role = "Application Server" })

  # Disable password authentication - samo SSH key
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.app_vm.id,
  ]

  # SSH Key konfiguracija
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  # OS Disk konfiguracija
  os_disk {
    name                 = "${var.project_name}-${var.environment}-app-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # Ubuntu 22.04 LTS Image
  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  # Cloud-init za osnovne postavke (opciono)
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - wget
      - vim
      - htop
    runcmd:
      - echo "Application VM initialized" > /var/log/cloud-init-done.log
  EOF
  )
}

# MONITORING VM - Za monitoring sistem
resource "azurerm_linux_virtual_machine" "monitoring_vm" {
  name                = "${var.project_name}-${var.environment}-monitoring-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = merge(var.tags, { Role = "Monitoring Server" })

  # Disable password authentication - samo SSH key
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.monitoring_vm.id,
  ]

  # SSH Key konfiguracija
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  # OS Disk konfiguracija
  os_disk {
    name                 = "${var.project_name}-${var.environment}-monitoring-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # Ubuntu 22.04 LTS Image
  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  # Cloud-init za osnovne postavke (opciono)
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - wget
      - vim
      - htop
      - mailutils
    runcmd:
      - echo "Monitoring VM initialized" > /var/log/cloud-init-done.log
  EOF
  )
}
