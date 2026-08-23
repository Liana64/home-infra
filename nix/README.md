# m1 — NAS / hypervisor host

NixOS host: ZFS storage + NFS for the milberry cluster, libvirt VM `talos-nas`
(worker, GTX 1080 passthrough) joining as m1. `br0` bridges the host's vlan-10
device (Proxmox-vmbr style): host address and VM taps ride untagged inside
the bridge, the wire is tagged — switch ports carry vlans 10/99/100 tagged.

## Layout

| Pool | Disks | Managed by | Contents |
|---|---|---|---|
| `rpool` | 2× NVMe mirror | disko | system, VM zvols (`vms/talos-os` 128G boot, `vms/talos-pool` 256G local-pool) |
| `tank` | 2× 28TB SATA mirror | manual | datasets + quotas + exports from `storage.nix`; sanoid snapshots |

Data pools are deliberately **not** in disko: `nixos-anywhere` re-runs can only
ever touch `rpool`. Reinstall = provision + `zpool import`. Accepted risks:
media is mirror + snapshots only (no off-site tier, consistent with B2-only
policy); host-down = node-down + cluster-storage-down (etcd unaffected: m1 is
a worker, quorum stays on n1–n3).

## Install

1. From the installer shell, verify the hardware guesses and adjust if needed:
   `ip -br link` → X710 ports = `enp2s0f0` (cluster, vlan 10) / `enp2s0f1`
   (mgmt, vlan 99), onboard 1G = `enp0s31f6` (home, vlan 100)
   (`configuration.nix`), `lspci -nn | grep 10de` → GPU at `01:00.x`
   (`vms.nix`), `lsblk -o NAME,MODEL` → boot NVMe = `nvme0n1`/`nvme1n1`
   (`disko.nix`; mirror is symmetric, order irrelevant).
2. Reserve stable IPs for all four MACs: X710 port 0 on cluster vlan (the NFS
   server address ends up in PV specs), port 1 on mgmt, onboard 1G on home,
   and the VM's `52:54:00:c0:fe:14` → `172.16.4.14`. ssh answers only on
   mgmt + home.
3. Mint the host's PQ age identity (see secretstore README), add its recipient
   and rekey, then install with the key staged:

   ```sh
   mkdir -p extra/var/lib/sops-nix && cp key.txt extra/var/lib/sops-nix/key.txt
   nix run github:nix-community/nixos-anywhere -- --flake .#m1 --extra-files extra root@<ip>
   ```

   Re-provisioning an existing host: add `--phases kexec,install` to skip disko
   (never reformat without intent). That phase needs root ssh, which the
   installed config refuses — kexec from the console, or boot the installer.
4. Create data pools (once):

   ```sh
   zpool create -o ashift=12 -o autoexpand=on -O compression=zstd -O atime=off \
     -O xattr=sa -O acltype=posixacl -O mountpoint=/tank tank \
     mirror <by-id-28T> <by-id-28T>
   zfs create -o mountpoint=none -o refreservation=50G tank/reserved
   systemctl restart zfs-datasets nfs-server
   ```

   Datasets, quotas, ownership, delegation, and exports reconcile from the
   `datasets` map in `storage.nix` (additive only — deletion and `zfs unallow`
   stay manual). Until the pool exists, `zfs-import-tank` and `zfs-datasets`
   fail on boot and hold back `nfs-server` — expected.

   `tank/home/<name>` is derived per normal user in `users.users`: declaring a
   user in `configuration.nix` is all it takes to get a private `0700` dataset
   exported to home + mgmt with real uids. Shared trees (`photos`, `shared`)
   stay `all_squash` to `documents`; the `tank/home` container itself is
   root-owned `0755` so it grants traversal only.

## Talos VM

1. `nixos-rebuild switch` defines and starts the domain (NixVirt, `active = true`).
   The factory ISO (pinned in `vms.nix`) sits at boot order 2: a blank zvol
   falls through to it and comes up in Talos maintenance mode.
2. The `m1` node entry already exists in `talconfig.yaml` (worker, nvidia
   image/patches, ip `172.16.4.14`): `talhelper genconfig`, then
   `talosctl apply-config --insecure -n 172.16.4.14 -f clusterconfig/milberry-m1.yaml`.
   Install lands on `sda` (`installDiskSelector: < 200gb`), reboot exits to disk
   via boot order.

## Backups

The framework pushes syncoid snapshots over ssh as the delegated `backup`
user (`zfs allow` on `tank/backups/framework`, no `destroy` — a stolen laptop
key can't shred history; the sanoid `backup` template prunes replicated
`autosnap_*` snaps locally as root). Mint a dedicated
key on the laptop, add it to `users.users.backup.openssh.authorizedKeys.keys`,
then:

```sh
syncoid --no-privilege-elevation --no-sync-snap \
  <dataset> backup@m1:tank/backups/framework/<name>
```

## Updates

```sh
nix flake update
nixos-rebuild switch --flake .#m1 --target-host liana@m1 --sudo --ask-sudo-password
```

sshd refuses root (`PermitRootLogin = "no"`), so deploys go over a wheel
account and `sudo -i` is the way to a root shell on the box.

Rollback: previous generation from GRUB. Domain XML changes are defined
immediately but applied only at the next VM power cycle (`restart = false`),
so host updates never bounce the cluster node.
