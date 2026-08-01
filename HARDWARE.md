# Hardware

Cluster `milberry` — Talos v1.12.6 / Kubernetes v1.35.2, three control-plane nodes, no workers.
Every node is a single Proxmox VM that owns its physical host; the host exists only to provide ZFS
and PCIe passthrough. VMs are declared in `tofu/projects/talos/main.tf`, Talos in
`kubernetes/main/bootstrap/talos/talconfig.yaml`.

- API VIP `172.16.4.10`, nodes `172.16.4.11-13` (VLAN 10)
- pods `10.244.0.0/16`, services `10.86.0.0/16`, LB pool `172.16.5.10-254` (Cilium L2)
- etcd quorum spans all three; n3 exists to make quorum survivable, nothing else

## Nodes

### n1 — 172.16.4.11
Minisforum MS-01. VM: 10 cores, 24 GiB. Two NICs (vmbr2, vmbr4).
Host storage is a single-disk ZFS pool: 1× WD Black SN770 1 TB → **no redundancy, disk loss is data loss**.
VM disks: 128 GB boot + 755 GB data.

General workload node. Runs the bulk-but-replaceable tier: media stack + downloads, the Postgres
replica, alertmanager, most filebrowser/scratch volumes. Also one of two `traefik-external`
DaemonSet nodes (with n2) under the pinned L2 policy.

### n2 — 172.16.4.12
Minisforum MS-01. VM: 14 cores, ~20 GiB usable (Tofu declares 26 GiB; GPU passthrough pins the
delta). Two NICs (vmbr2, vmbr1).
Host storage is a ZFS mirror (`local-mirror`): 2× 2 TB NVMe (Viper VP4300 + WD Black SN770 2 TB) →
**the only redundant tier in the cluster; irreplaceable data belongs here**.
VM disks: 128 GB boot + 1280 GB data.

GTX 1080 in a Thunderbolt eGPU enclosure, passed through; Talos carries the nvidia LTS kmod +
container toolkit extensions and advertises `nvidia.com/gpu: 4` (time-sliced). GPU consumers:
llama-cpp, immich (+ ML), jellyfin transcode. Pascal-era, so CUDA 12.8 is the ceiling.

Node-pinned by affinity: syncthing, immich. Sole L2 announcer for `syncthing-sync`.

### n3 — 172.16.4.13
Dell OptiPlex 7050. VM: 4 cores, 3.5 GiB. One NIC. Datastore `local-ssd`, VM disks 128 GB + 512 GB.
Tainted `node-role.kubernetes.io/etcd-only=true:NoSchedule` — **quorum member only**. Its 512 GB data
disk is mounted and idle (2% used); no PVs land there while the taint stands.

## Storage

Two provisioners, both `openebs.io/local`, both `WaitForFirstConsumer`, `Delete` reclaim,
**no volume expansion**. There is no networked/shared storage anywhere in the cluster.

| StorageClass | Backing path | Backed by | Notes |
| --- | --- | --- | --- |
| `cluster-nvme` | `/var/mnt/local-pool` | VM data disk (`/dev/sdb`), bind-mounted into kubelet | default for app data |
| `openebs-hostpath` | `/var/openebs/local` | VM **boot** disk | volsync default (`VOLSYNC_STORAGECLASS`); one real PVC (`security/pocket-id`) |

Consequences that drive architecture:

- Every PV is node-local with hard `nodeAffinity`. A PVC permanently pins its pod to one node; a
  node loss takes its apps offline until restored from backup. Multi-attach and rescheduling are
  not options.
- Resizing means recreate + restore, not `kubectl edit`.
- Durability tiering is manual: pick n2 (mirror) via affinity for anything you would grieve, leave
  the rest on n1.
- Backups are the only redundancy for n1 data — volsync/kopia to Backblaze B2 (`copyMethod: Direct`,
  every 12 h). No onsite tier.

### Pool usage

| Node | Pool | Size | Used | Free | Subscribed (PVC requests) |
| --- | --- | --- | --- | --- | --- |
| n1 | `/var/mnt/local-pool` | 754.6G | 684.6G | 70.0G (**91%**) | 750 GiB |
| n1 | `/var/openebs/local` | 125.8G | 95.6G | 30.2G (76%) | — |
| n2 | `/var/mnt/local-pool` | 1.2T | 183.4G | 1.1T (14%) | 1261 GiB |
| n2 | `/var/openebs/local` | 125.7G | 83.8G | 42.0G (67%) | 2 GiB |
| n3 | `/var/mnt/local-pool` | 511.7G | 9.8G | 501.9G (2%) | — |
| n3 | `/var/openebs/local` | 125.8G | 7.2G | 118.6G (6%) | — |

Requests are not reservations — hostpath volumes have no quota, so subscription can exceed the pool
(n1: 750 GiB subscribed on 755 GB). **n1 is effectively full**; new PVCs there need reclaim first.
n2 is oversubscribed on paper (1261 GiB / 1.2 T) but the two large claims are sparse — syncthing
700 GiB and immich 256 GiB dominate the ceiling.

Largest claims: `home/syncthing` 700Gi (n2), `media/qbittorrent-media` 512Gi (n1),
`home/immich-data` 256Gi (n2), `database/postgres-1-{1,2}` 128Gi each (n2/n1),
`observability/prometheus` 75Gi (n2), `ai/llama-cpp` 50Gi (n2, model weights).

Refresh these numbers with `task talos:disks -- <node>`.

## Compute headroom

| Node | CPU req / cap | Mem req / cap | Schedulable |
| --- | --- | --- | --- |
| n1 | 6860m / 10 (68%) | 15.4 GiB / 23.4 GiB (67%) | yes |
| n2 | 5440m / 14 (38%) | 15.1 GiB / 19.4 GiB (80%) | yes, + 4 GPU slices |
| n3 | 660m / 4 (16%) | 1.7 GiB / 2.7 GiB (62%) | no (tainted) |

Memory limits are deliberately overcommitted (269% on n1) — infra and backup-critical workloads get
requests only, never memory limits; leaf apps get memory limits and never CPU limits.

## Known drift

`hostpci` for the GTX 1080 is commented out in `tofu/projects/talos/main.tf` while the card is live
and advertised on n2 — a `tofu apply` would detach it.
