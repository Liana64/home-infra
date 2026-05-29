terraform {
  required_version = ">= 1.6"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.101"
    }
  }
}

variable "proxmox_hosts" {
  description = "Per-host credentials. Keys must match the target node."
  sensitive   = true
  type = map(object({
    endpoint = string
    username = optional(string, "root@pam")
    password = string
  }))
}

provider "proxmox" {
  endpoint = var.proxmox_hosts[var.target_node].endpoint
  username = var.proxmox_hosts[var.target_node].username
  password = var.proxmox_hosts[var.target_node].password
  insecure = true

  # API auth runs as root@pam (only root may set the `args:` line). Node-level
  # operations (qcow2 disk import) go over SSH as an unprivileged user with
  # NOPASSWD sudo, so no root SSH access is granted. The provider prepends
  # sudo automatically for pvesm/qm/tee.
  ssh {
    agent    = true
    username = "ansible"
  }
}
