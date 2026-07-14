{ pkgs, lib, ... }: {

  home.username = "mani";
  home.homeDirectory = lib.mkDefault "/home/mani"; # override per-host
  home.stateVersion = "24.11";
  imports = [./programs];

  home.packages = with pkgs; [
    neovim
    lazygit
    python3
  ];

  programs.git = {
    enable = true;
    settings.user = {
	    name = "mani";
      email = "tismani@protonmail.com";
    };
    signing.format = null;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "eza -l -g --icons";
      cat = "bat";
      cd = "z";
      # no #hostname attribute needed: *-rebuild defaults to the current hostname
      rebuild =
      if pkgs.stdenv.isDarwin
      then "sudo darwin-rebuild switch --flake ~/dotfiles"
      else "sudo nixos-rebuild switch --flake ~/dotfiles";
    };
    initContent = ''
      eval "$(zoxide init zsh)"
    '';
  };

  programs.home-manager.enable = true;
}
