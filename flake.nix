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
    calendar = {
      url = "github:bhr-tools/Calendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mail = {
      url = "github:bhr-tools/Mail";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    inventory = {
      url = "github:bhr-tools/Inventory";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dictee = {
      url = "github:bhr-tools/Dictee";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    meals = {
      url = "github:bhr-tools/Meals";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    project = {
      # Private repository: fetched over SSH (the key of whoever rebuilds).
      url = "git+ssh://git@github.com/bhr-tools/Project";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wip = {
      # Personal site (private repository). Only the NixOS module and node_modules come from
      # here: the server fetches and builds main itself (services.wip).
      url = "git+ssh://git@github.com/ben-hourlier/wip";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, focus, getDone, calendar, mail, inventory, dictee, meals, project, wip, ... }: {
    nixosConfigurations.server1-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
        focus.nixosModules.default
        getDone.nixosModules.default
        calendar.nixosModules.default
        mail.nixosModules.default
        inventory.nixosModules.default
        dictee.nixosModules.default
        meals.nixosModules.default
        project.nixosModules.default
        wip.nixosModules.default
      ];
    };
  };
}
