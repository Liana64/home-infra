# home-infra

This is my kubernetes homelab, currently running on a cluster of MinisForum devices. Photos to be added when I finish the enclosure.

<details>
  <summary>Click here to see my high-level network diagram</summary>

  <img src="https://raw.githubusercontent.com/Liana64/home-infra/refs/heads/main/docs/homelab.jpg" align="center" width="600px" alt="Network Diagram" />
</details>

## Features (Old)

- [Talos](https://github.com/siderolabs/talos) OS for immutability, security, performance, ease-of-use. For my homelab, I've deployed this on Proxmox so I'm using nocloud, but for a bare metal install there are a lot of great tools you can use
- Automation, including GitOps using [FluxCD](https://github.com/fluxcd/flux2), [Reloader](https://github.com/stakater/Reloader), and other deployments
- Local OCI registry mirror using [spegel](https://github.com/spegel-org/spegel)
- [Cert-manager](https://github.com/cert-manager/cert-manager) with LetsEncrypt and DNS authorization
- [Cilium](https://github.com/cilium/cilium) container networking and CoreDNS with network policies for most things
- Secrets encrypted using a mix of [SOPS](https://github.com/getsops/sops) and [external-secrets](https://github.com/external-secrets/external-secrets) accessing Bitwarden
- OIDC authentication with [Authelia](https://github.com/authelia/authelia) and [LLDAP](https://github.com/lldap/lldap) (TODO: Reimplement this)
- [Traefik](https://github.com/traefik/traefik) internal and external ingress with hardened security and [Anubis](https://github.com/TecharoHQ/anubis) to block AI crawlers
- Databases for [Cloudnative PG](https://github.com/cloudnative-pg/cloudnative-pg), [MinIO](https://min.io/), [Dragonfly](https://github.com/dragonflydb/dragonfly), [Mosquitto](https://github.com/eclipse-mosquitto/mosquitto), and, if you can find it in my archive, [MS SQL Server](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- Storage managed by [OpenEBS](https://github.com/openebs/openebs)
- Various drivers and utilities
- Observability tools and exporters including Prometheus, Grafana, Loki, and others
- Many self-hosted deployments, including a [Homepage](https://github.com/gethomepage/homepage), game servers, a media stack, and my personal website
- Taskfiles ([go-task](https://taskfile.dev/)) and scripts for ease-of-use

## Requirements

- [Taskfile](https://taskfile.dev/)
- [Direnv](https://github.com/direnv/direnv)
- [Talosctl](https://github.com/siderolabs/talos)
- [SOPS](https://github.com/getsops/sops)
- [age](https://github.com/FiloSottile/age)

## Credit

- [bjw-s](https://github.com/bjw-s/helm-charts) for app-template
- [brettinternet](https://github.com/brettinternet/homeops) for inspiration
- [onedr0p](https://github.com/onedr0p/home-ops) for inspiration
