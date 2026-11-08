# home-infra

This is my kubernetes homelab, currently running on a cluster of MinisForum devices. Photos to be added when I finish the enclosure.

<details>
  <summary>Click here to see my high-level network diagram</summary>

  <img src="https://raw.githubusercontent.com/Liana64/nixops/refs/heads/main/docs/diagrams/network.svg" align="center" width="600px" alt="Network Diagram" />
</details>

## Features

- Landrun (landlocked) entrypoint for public-facing apps
- Taskfiles ([go-task](https://taskfile.dev/)) and scripts for ease-of-use
- The normal things you would expect

## Requirements

- [Taskfile](https://taskfile.dev/)
- [Talosctl](https://github.com/siderolabs/talos)
- [SOPS](https://github.com/getsops/sops)
- [age](https://github.com/FiloSottile/age)

## Credit

- [bjw-s](https://github.com/bjw-s/helm-charts) for app-template
- [brettinternet](https://github.com/brettinternet/homeops) for inspiration
- [onedr0p](https://github.com/onedr0p/home-ops) for inspiration
