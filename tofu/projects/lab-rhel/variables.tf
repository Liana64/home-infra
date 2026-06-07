variable "target_node" {
  type    = string
  default = "n3"
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
