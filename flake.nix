{
  description = "My nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # AMD AI inference stack (Lemonade + ROCm/NPU backends) for Strix Halo.
    # Intentionally NOT following nixpkgs: the upstream overrides re-hash
    # against a different nixpkgs and every backend rebuilds from source.
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
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
          home-manager.nixosModules.home-manager
          homeManagerConfig
        ];
      };

    };
}
