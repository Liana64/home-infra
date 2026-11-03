variable "name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "target_node" {
  type    = string
  default = "pve"
}

variable "cores" {
  type    = number
  default = 10
}

variable "sockets" {
  type    = number
  default = 1
}

variable "cpu_type" {
  type    = string
  default = "x86-64-v2-AES"
}

variable "memory" {
  type    = number
  default = 24576
}

variable "iso" {
  type    = string
  default = "local:iso/nocloud-amd64-secureboot.iso"
}

variable "datastore_id" {
  type    = string
  default = "local-pool"
}

variable "disks" {
  type = list(object({
    size        = number
    ssd         = optional(bool, true)
    aio         = optional(string, "native")
    file_id     = optional(string)
    file_format = optional(string, "raw")
  }))
  default = [{ size = 128 }]
}

variable "cloud_init" {
  type = object({
    datastore_id = optional(string)
    interface    = optional(string, "ide0")
    user_account = optional(object({
      username = string
      password = optional(string)
      keys     = optional(list(string), [])
    }))
    dns = optional(object({
      domain  = optional(string)
      servers = optional(list(string))
    }))
    ip_config = optional(list(object({
      ipv4 = optional(object({ address = optional(string), gateway = optional(string) }))
      ipv6 = optional(object({ address = optional(string), gateway = optional(string) }))
    })), [])
  })
  default = null
}

variable "networks" {
  type = list(object({
    bridge      = string
    vlan_id     = optional(number)
    firewall    = optional(bool, true)
    mac_address = optional(string)
  }))
}

variable "startup_order" {
  type    = string
  default = "10"
}

variable "smbios_uuid" {
  type    = string
  default = null
}

variable "on_boot" {
  type    = bool
  default = true
}

variable "started" {
  type    = bool
  default = true
}

variable "serial_device" {
  type    = string
  default = null
}

variable "hostpci" {
  type = list(object({
    mapping  = optional(string)
    id       = optional(string)
    pcie     = optional(bool)
    rombar   = optional(bool)
    xvga     = optional(bool)
    rom_file = optional(string)
    mdev     = optional(string)
  }))
  default = []
}

# Appended to qemu-server's `args:` line. PVE's sanctioned escape hatch for
# devices it doesn't model natively (e.g. virtual usb-storage backed by a file).
variable "kvm_arguments" {
  type    = string
  default = null
}
