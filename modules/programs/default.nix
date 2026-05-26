{ pkgs, ... }: {

  imports = [
    ./fish.nix
  ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
