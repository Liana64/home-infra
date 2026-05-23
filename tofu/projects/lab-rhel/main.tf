locals {
  qcow2_filename_map = {
    "8.4"  = "rhel-8.4-x86_64-kvm.qcow2"
    "9.2"  = "rhel-9.2-x86_64-kvm.qcow2"
    "10.1" = "rhel-10.1-x86_64-kvm.qcow2"
  }

  # Build a keyed map so terraform_data and the VM module can for_each over
  # the same set of labs. Keyed by version string so VM identity is stable
  # regardless of list ordering.
  labs = {
    for idx, ver in var.rhel_versions :
    ver => {
      qcow2_filename   = local.qcow2_filename_map[ver]
      qcow2_local_path = "${path.module}/images/${local.qcow2_filename_map[ver]}"
      # PVE's iso content parser accepts .iso/.img but older versions reject
      # .qcow2 (parse error: "unable to parse directory volume name"). Stage
      # under a .img name; file_format="qcow2" on the disk tells the import
      # path what the bytes actually are.
      staged_filename = replace(local.qcow2_filename_map[ver], ".qcow2", ".img")
      vm_name         = "lab-rhel${split(".", ver)[0]}-${var.target_node}"
      vm_id           = var.vm_id_base + idx
    }
  }
}

# The bpg provider uploads `proxmox_virtual_environment_file` through PVE's
# HTTP API, which chokes on large qcow2 files (pveproxy closes the
# connection mid-stream). Stage via scp using the ansible service account
# (NOPASSWD sudo, agent auth), then reference the staged path.
resource "terraform_data" "rhel_qcow2" {
  for_each = local.labs

  triggers_replace = {
    file_hash = filemd5(each.value.qcow2_local_path)
    target    = var.target_node
    filename  = each.value.staged_filename
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      scp -o StrictHostKeyChecking=accept-new \
        ${each.value.qcow2_local_path} \
        ansible@${var.target_node}.lianas.org:/tmp/${each.value.staged_filename}
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${var.target_node}.lianas.org \
        sudo install -m 0644 -o root -g root \
          /tmp/${each.value.staged_filename} \
          /var/lib/vz/template/iso/${each.value.staged_filename}
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${var.target_node}.lianas.org \
        rm -f /tmp/${each.value.staged_filename}
    EOT
  }

  # Clean up the staged image on destroy. Destroy provisioners can only see
  # `self`, so we pull filename/target from triggers_replace.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${self.triggers_replace.target}.lianas.org \
        sudo rm -f /var/lib/vz/template/iso/${self.triggers_replace.filename}
    EOT
  }
}

module "vm" {
  for_each = local.labs
  source   = "../../modules/proxmox-vm"

  target_node  = var.target_node
  datastore_id = var.datastore_id
  iso          = "none"

  name   = each.value.vm_name
  vm_id  = each.value.vm_id
  cores  = 2
  memory = 1536

  disks = [
    {
      size        = 20
      file_id     = "${var.image_datastore_id}:iso/${each.value.staged_filename}"
      file_format = "qcow2"
    },
    { size = 12 },
    { size = 8 },
  ]

  networks = [{ bridge = "vmbr1", vlan_id = 80 }]

  cloud_init = {
    user_account = {
      username = var.admin_username
      password = var.admin_password
      keys     = var.ssh_public_keys
    }
    dns = { servers = ["1.1.1.1", "9.9.9.9"] }
    ip_config = [{
      ipv4 = {
        address = var.ip_config.ipv4_address
        gateway = var.ip_config.ipv4_gateway
      }
    }]
  }

  depends_on = [terraform_data.rhel_qcow2]
}

output "labs" {
  description = "Map of deployed labs keyed by RHEL version."
  value = {
    for ver, lab in local.labs :
    ver => {
      vm_id          = module.vm[ver].vm_id
      vm_name        = lab.vm_name
      ipv4_addresses = module.vm[ver].ipv4_addresses
    }
  }
}
