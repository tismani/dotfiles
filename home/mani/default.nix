{ pkgs, lib, ... }: {

  home.username = "mani";
  home.homeDirectory = lib.mkDefault "/home/mani"; # override per-host
  home.stateVersion = "24.11";
  imports = [./programs];

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
      ls = "eza -l -g --icons";
      cat = "bat";
      rebuild = "sudo darwin-rebuild switch --flake ~/dotfiles#nightfury";
      cd = "z";
    };
    initContent = ''
      eval "$(zoxide init zsh)"
    '';
  };

  programs.home-manager.enable = true;
}
