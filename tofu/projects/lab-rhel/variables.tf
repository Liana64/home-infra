variable "rhel_versions" {
  type        = list(string)
  description = "RHEL versions to deploy. Each entry spawns its own VM."
  default     = ["8.4", "9.2", "10.2"]

  validation {
    condition     = alltrue([for v in var.rhel_versions : contains(["8.4", "9.2", "10.2"], v)])
    error_message = "Supported versions: 8.4, 9.2, 10.2. Add more to qcow2_filename_map in main.tf."
  }
}

variable "target_node" {
  type    = string
  default = "n3"
}

variable "vm_id_base" {
  type        = number
  description = "Each lab VM gets vm_id_base + its index in rhel_versions."
  default     = 400
}

variable "datastore_id" {
  type        = string
  description = "Datastore for VM disks, EFI, TPM, cloud-init."
  default     = "local-ssd"
}

variable "image_datastore_id" {
  type        = string
  description = "Datastore where staged qcow2 images live on the PVE node."
  default     = "local"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys to inject via cloud-init."
}

variable "admin_username" {
  type    = string
  default = "cloud-user"
}

variable "admin_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "ip_config" {
  type = object({
    ipv4_address = optional(string, "dhcp")
    ipv4_gateway = optional(string)
  })
  default = {}
}
