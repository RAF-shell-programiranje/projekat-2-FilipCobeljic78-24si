# ------------------------------------------------------------------------------
# PUBLIC IP ADDRESSES
# ------------------------------------------------------------------------------

output "app_vm_public_ip" {
  description = "Public IP address of Application VM (za SSH pristup)"
  value       = azurerm_public_ip.app_vm.ip_address
}

output "monitoring_vm_public_ip" {
  description = "Public IP address of Monitoring VM (za SSH pristup)"
  value       = azurerm_public_ip.monitoring_vm.ip_address
}

# ------------------------------------------------------------------------------
# PRIVATE IP ADDRESSES
# ------------------------------------------------------------------------------

output "app_vm_private_ip" {
  description = "Private IP address of Application VM (internal communication)"
  value       = azurerm_network_interface.app_vm.private_ip_address
}

output "monitoring_vm_private_ip" {
  description = "Private IP address of Monitoring VM (internal communication)"
  value       = azurerm_network_interface.monitoring_vm.private_ip_address
}

# ------------------------------------------------------------------------------
# RESOURCE IDENTIFIERS
# ------------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource Group name (za cleanup sa 'az group delete')"
  value       = azurerm_resource_group.main.name
}

output "app_vm_name" {
  description = "Application VM name"
  value       = azurerm_linux_virtual_machine.app_vm.name
}

output "monitoring_vm_name" {
  description = "Monitoring VM name"
  value       = azurerm_linux_virtual_machine.monitoring_vm.name
}

# ------------------------------------------------------------------------------
# SSH CONNECTION STRINGS
# ------------------------------------------------------------------------------

output "app_vm_ssh_command" {
  description = "SSH command za pristup Application VM-u"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.app_vm.ip_address}"
}

output "monitoring_vm_ssh_command" {
  description = "SSH command za pristup Monitoring VM-u"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.monitoring_vm.ip_address}"
}

# ------------------------------------------------------------------------------
# ANSIBLE INVENTORY (JSON format)
# ------------------------------------------------------------------------------

output "ansible_inventory" {
  description = "Ansible inventory u JSON formatu (za automatsko generisanje inventory.ini)"
  value = jsonencode({
    app_server = {
      hosts = {
        (azurerm_linux_virtual_machine.app_vm.name) = {
          ansible_host = azurerm_public_ip.app_vm.ip_address
          ansible_user = var.admin_username
          ansible_ssh_private_key_file = replace(var.ssh_public_key_path, ".pub", "")
          private_ip = azurerm_network_interface.app_vm.private_ip_address
        }
      }
    }
    monitoring_server = {
      hosts = {
        (azurerm_linux_virtual_machine.monitoring_vm.name) = {
          ansible_host = azurerm_public_ip.monitoring_vm.ip_address
          ansible_user = var.admin_username
          ansible_ssh_private_key_file = replace(var.ssh_public_key_path, ".pub", "")
          private_ip = azurerm_network_interface.monitoring_vm.private_ip_address
        }
      }
    }
  })
}

# ------------------------------------------------------------------------------
# DEPLOYMENT SUMMARY
# ------------------------------------------------------------------------------

output "deployment_summary" {
  description = "Rezime deployment-a sa svim ključnim informacijama"
  value = {
    region            = var.location
    resource_group    = azurerm_resource_group.main.name
    app_vm_ip         = azurerm_public_ip.app_vm.ip_address
    monitoring_vm_ip  = azurerm_public_ip.monitoring_vm.ip_address
    ssh_user          = var.admin_username
    vm_size           = var.vm_size
    disk_type         = var.os_disk_type
    tags              = var.tags
  }
}