terraform {
  required_version = ">= 1.6"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

variable "proxmox_hosts" {
  description = "Per-host credentials. Keys must match the provider aliases below."
  sensitive   = true
  type = map(object({
    endpoint = string
    username = optional(string, "root@pam")
    password = string
  }))
}

provider "proxmox" {
  alias    = "ms-01"
  endpoint = var.proxmox_hosts["ms-01"].endpoint
  username = var.proxmox_hosts["ms-01"].username
  password = var.proxmox_hosts["ms-01"].password
  insecure = true
}

provider "proxmox" {
  alias    = "n2"
  endpoint = var.proxmox_hosts["n2"].endpoint
  username = var.proxmox_hosts["n2"].username
  password = var.proxmox_hosts["n2"].password
  insecure = true
}

provider "proxmox" {
  alias    = "n3"
  endpoint = var.proxmox_hosts["n3"].endpoint
  username = var.proxmox_hosts["n3"].username
  password = var.proxmox_hosts["n3"].password
  insecure = true
}
