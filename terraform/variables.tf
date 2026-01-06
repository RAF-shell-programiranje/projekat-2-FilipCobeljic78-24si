# ==============================================================================
# AZURE REGION CONFIGURATION
# ==============================================================================

variable "location" {
  description = "Azure region gde će se kreirati svi resursi"
  type        = string
  default     = "norwayeast"

  validation {
    condition     = can(regex("^(norwayeast|francecentral|eastus|westeurope|northeurope|westus2|centralus)$", var.location))
    error_message = "Location mora biti jedna od podržanih regiona: norwayeast, francecentral, eastus, westeurope, northeurope, westus2, centralus."
  }
}

# ==============================================================================
# RESOURCE NAMING
# ==============================================================================

variable "project_name" {
  description = "Naziv projekta - koristi se kao prefiks za sve resurse"
  type        = string
  default     = "dummy-service"

  validation {
    condition     = length(var.project_name) <= 20 && can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name mora biti maksimalno 20 karaktera i sadržati samo lowercase slova, brojeve i crtice."
  }
}

variable "environment" {
  description = "Okruženje (dev, test, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^(dev|test|prod)$", var.environment))
    error_message = "Environment mora biti: dev, test ili prod."
  }
}

# ==============================================================================
# VIRTUAL MACHINE CONFIGURATION
# ==============================================================================

variable "vm_size" {
  description = "Veličina Azure VM-a (SKU)"
  type        = string
  default     = "Standard_D2s_v3"

  # Standard_D2s_v3: 2 vCPU, 8 GB RAM - bolje performanse
  # Standard_B1s: 1 vCPU, 1 GB RAM - najjeftiniji za testiranje (~8 EUR/mesec)
  # Standard_B2s: 2 vCPU, 4 GB RAM - bolje performanse (~30 EUR/mesec)
}

variable "admin_username" {
  description = "Admin korisničko ime za SSH pristup VM-ovima"
  type        = string
  default     = "azureuser"

  validation {
    condition     = length(var.admin_username) >= 3 && length(var.admin_username) <= 32
    error_message = "Admin username mora biti između 3 i 32 karaktera."
  }
}

variable "ssh_public_key_path" {
  description = "Putanja do SSH public key fajla (~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# ==============================================================================
# OS DISK CONFIGURATION
# ==============================================================================

variable "os_disk_size_gb" {
  description = "Veličina OS diska u GB"
  type        = number
  default     = 30

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 1024
    error_message = "OS disk mora biti između 30 GB i 1024 GB."
  }
}

variable "os_disk_type" {
  description = "Tip OS diska (Standard_LRS, Premium_LRS, StandardSSD_LRS)"
  type        = string
  default     = "Standard_LRS"

  # Standard_LRS: Najjeftiniji, HDD (~4 EUR/mesec za 30GB)
  # StandardSSD_LRS: SSD, brži (~6 EUR/mesec za 30GB)
  # Premium_LRS: Najbrži, potreban za Premium VM-ove

  validation {
    condition     = can(regex("^(Standard_LRS|Premium_LRS|StandardSSD_LRS)$", var.os_disk_type))
    error_message = "OS disk type mora biti: Standard_LRS, Premium_LRS ili StandardSSD_LRS."
  }
}

# ==============================================================================
# NETWORK SECURITY CONFIGURATION
# ==============================================================================

variable "allowed_ssh_source_ips" {
  description = "Lista IP adresa koje mogu pristupiti SSH-u (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # PAŽNJA: Ovo dozvoljava pristup sa bilo koje IP adrese!

  # Za produkciju, zameni sa tvojom IP adresom:
  # default = ["123.456.789.0/32"]
  # 
  # Možeš pronaći svoju javnu IP adresu sa: curl ifconfig.me
}

variable "application_port" {
  description = "Port na kojem radi Java aplikacija (ako je potreban eksterni pristup)"
  type        = number
  default     = 8080

  validation {
    condition     = var.application_port > 0 && var.application_port < 65536
    error_message = "Application port mora biti između 1 i 65535."
  }
}

variable "enable_public_app_access" {
  description = "Da li omogućiti javni pristup aplikaciji preko application_port"
  type        = bool
  default     = false

  # Za dummy service koji samo piše u log, ostavi false
  # Za web aplikaciju, postavi na true
}

# ==============================================================================
# MONITORING CONFIGURATION
# ==============================================================================

variable "monitoring_port" {
  description = "Port za monitoring sistem (ako je potreban)"
  type        = number
  default     = 9090

  validation {
    condition     = var.monitoring_port > 0 && var.monitoring_port < 65536
    error_message = "Monitoring port mora biti između 1 i 65535."
  }
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "tags" {
  description = "Azure resource tags za sve resurse"
  type        = map(string)
  default = {
    Project     = "Dummy Service Deployment"
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

# ==============================================================================
# VM IMAGE CONFIGURATION
# ==============================================================================

variable "vm_image_publisher" {
  description = "Publisher Linux image-a"
  type        = string
  default     = "Canonical"
}

variable "vm_image_offer" {
  description = "Offer Linux image-a"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "vm_image_sku" {
  description = "SKU Linux image-a (Ubuntu 22.04 LTS)"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "vm_image_version" {
  description = "Verzija Linux image-a"
  type        = string
  default     = "latest"
}