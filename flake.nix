{
  description = "My nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, ... }: {

    darwinConfigurations."nightfury" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/nightfury
        ./modules/common
        ./modules/programs
        home-manager.darwinModules.home-manager
        { home-manager.users.mani = import ./home/mani; }
      ];
    };

    nixosConfigurations."flagship" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/flagship
        ./modules/common
        ./modules/programs
        home-manager.nixosModules.home-manager
        { home-manager.users.mani = import ./home/mani; }
      ];
    };

  };
}
