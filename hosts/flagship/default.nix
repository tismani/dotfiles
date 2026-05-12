{ pkgs, inputs, config, ... }: {

  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "flagship";
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Asia/Riyadh";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.mani = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  system.stateVersion = "24.11";
}
