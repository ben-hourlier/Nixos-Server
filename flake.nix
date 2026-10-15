{
  description = "Server EliteDesk 800 G4";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    focus = {
      url = "github:bhr-tools/Focus";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    getDone = {
      url = "github:bhr-tools/GetDone";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, focus, getDone, ... }: {
    nixosConfigurations.server1-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
        focus.nixosModules.default
        getDone.nixosModules.default
      ];
    };
  };
}
