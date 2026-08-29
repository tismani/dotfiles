{
  config,
  lib,
  ...
}:
{
  programs = {
    starship = {
      enable = true;
      # fish integration is manual — see modules/programs/fish.nix (system-managed fish).
      # nerd-font-symbols preset downloaded from starship website
      settings = builtins.fromTOML (builtins.readFile ./nerd-font-symbols.toml);
    };
  };
}
