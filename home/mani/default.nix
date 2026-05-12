{ pkgs, lib, ... }: {

  home.username = "mani";
  home.homeDirectory = lib.mkDefault "/home/mani"; # override per-host
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    neovim
    tmux
    lazygit
    nodejs_22
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
      ls = "eza --icons";
      cat = "bat";
      rebuild = "sudo darwin-rebuild switch --flake ~/dotfiles#nightfury";
    };
  };

  programs.home-manager.enable = true;
}
