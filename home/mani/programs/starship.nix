{
  config,
  lib,
  ...
}:
{
  programs = {
    starship = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      # nerd-font-symbols preset downloaded from starship website
      settings = builtins.fromTOML (builtins.readFile ./nerd-font-symbols.toml);
    };
  };
}
