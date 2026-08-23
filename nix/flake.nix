{
  description = "m1 — NixOS hypervisor + storage host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Liana64/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@git.milberry.org/liana/secrets.git";
      flake = false;
    };
  };

  outputs = {
    nixpkgs,
    disko,
    nixvirt,
    sops-nix,
    ...
  } @ inputs: {
    nixosConfigurations.m1 = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        disko.nixosModules.disko
        nixvirt.nixosModules.default
        sops-nix.nixosModules.sops
        ./m1/configuration.nix
        ./m1/disko.nix
        ./m1/secrets.nix
        ./m1/storage.nix
        ./m1/vms.nix
      ];
    };
  };
}
