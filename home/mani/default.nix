{ pkgs, lib, ... }: {

  home.username = "mani";
  home.homeDirectory = lib.mkDefault "/home/mani"; # override per-host
  home.stateVersion = "24.11";
  # The Linux-only desktop (niri + noctalia) is imported per-host from
  # hosts/halo/desktop.nix, so nightfury (darwin) never evaluates it.
  imports = [ ./programs ];

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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.home-manager.enable = true;
}
