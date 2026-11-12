{
  description = "My nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Stable nixpkgs, used only to pin packages whose unstable build is broken
    # (currently open-webui on halo — see hosts/halo/openwebui.nix).
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # AMD AI inference stack (Lemonade + ROCm/NPU backends) for Strix Halo.
    # Intentionally NOT following nixpkgs: the upstream overrides re-hash
    # against a different nixpkgs and every backend rebuilds from source.
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";

    # Native Strix Halo inference backend. Intentionally NOT following
    # nixpkgs: Gufo pins the ROCm toolchain it qualifies and builds against.
    gufo.url = "github:gufo-org/gufo";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System-wide theming (Dracula). Applies to NixOS, nix-darwin and, because
    # home-manager is wired in as a system module, our home config too.
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets: age-encrypted in secrets/, decrypted on each host at activation.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative *arr + Jellyfin media stack (ajwa only).
    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixos-hardware, nix-darwin, home-manager, ... }:
    let
      homeManagerConfig = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          # Wired now so user-level secrets (SSH keys) can move into sops later.
          sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
          users.mani = import ./home/mani;
        };
      };
    in {

      darwinConfigurations."nightfury" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nightfury
          ./modules/common
          ./modules/programs
          inputs.stylix.darwinModules.stylix
          inputs.sops-nix.darwinModules.sops
          home-manager.darwinModules.home-manager
          homeManagerConfig
        ];
      };

      nixosConfigurations."halo" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/halo/configuration.nix
          ./modules/common
          ./modules/programs
          inputs.nix-amd-ai.nixosModules.default
          nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          homeManagerConfig
        ];
      };

      nixosConfigurations."ajwa" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/ajwa/configuration.nix
          inputs.nixflix.nixosModules.default
          ./modules/common
          ./modules/programs
          inputs.stylix.nixosModules.stylix
          inputs.sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          homeManagerConfig
        ];
      };

    };
}
