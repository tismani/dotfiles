{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./power.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ajwa"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Riyadh";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Same stylix/GNOME clash as halo: stylix's NixOS qt target picks "gnome",
  # which its home-manager target rejects. See hosts/halo/configuration.nix.
  stylix.targets.qt.platform = lib.mkForce "qtct";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mani = {
    isNormalUser = true;
    description = "mani";
    shell = pkgs.fish;
    # docker lets mani use the daemon without sudo — effectively root on ajwa.
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    git
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Use the regular OpenSSH daemon for remote access.
  services.openssh = {
    enable = true;
    settings = {
      AllowUsers = [ "mani" ];
      PermitRootLogin = "no";
      PasswordAuthentication = true; # Temporary until mani has an authorized key.
      KbdInteractiveAuthentication = false;
    };
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration.
  system.stateVersion = "26.05"; # Did you read the comment?

}
