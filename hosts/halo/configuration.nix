{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./llm.nix
      ./flatpak.nix
      ./desktop.nix
      ./power.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  services.fwupd.enable = true;

  networking.hostName = "halo"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Riyadh";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };


  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # niri (see desktop.nix) is off for now — GNOME only.
  desktop.niri.enable = false;

  # Because GNOME is enabled, stylix's NixOS qt target defaults the platform to
  # "gnome", which its own home-manager target rejects (only "qtct" is
  # supported) and which also sets the deprecated qt.platformTheme.name =
  # "gnome". Pin qtct here rather than in the home config: it propagates to
  # home-manager via stylix.homeManagerIntegration.followSystem, so it applies
  # whether or not the niri desktop module is enabled. Qt apps are then themed
  # by stylix through qt5ct/qt6ct instead of GNOME's adwaita platform theme.
  # mkForce because stylix's own NixOS module sets "gnome" at normal priority.
  stylix.targets.qt.platform = lib.mkForce "qtct";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mani = {
    isNormalUser = true;
    description = "mani";
    # video + render give the lemonade/NPU service user GPU device access.
    # netbird grants access to the hardened daemon's protected control socket.
    extraGroups = [ "networkmanager" "netbird" "wheel" "video" "render" ];
    # Rootless Podman needs subordinate IDs for container users and groups.
    subUidRanges = [{ startUid = 100000; count = 65536; }];
    subGidRanges = [{ startGid = 100000; count = 65536; }];
  };

  # Install firefox.
  programs.firefox.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  virtualisation.podman.enable = true;

  environment.systemPackages = with pkgs; [
    btop
    codex
    python3Packages.huggingface-hub # Hugging Face CLI (hf)
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    # Bitwarden is installed as a Flatpak instead (see flatpak.nix) — clipboard
    # copy is broken in the nixpkgs build.
  ];

  # Run Electron apps natively on Wayland instead of through XWayland; the
  # nixpkgs Electron wrappers only pass --ozone-platform-hint=auto when this is
  # set. Applies to VSCode, Postman and anything else Chromium-based, and buys
  # proper HiDPI scaling. Flatpaks don't see it — they carry their own wrappers.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # List services that you want to enable:

  # NetBird's embedded SSH server cannot switch local users when the daemon is
  # unprivileged. Use the regular OpenSSH daemon for remote access instead.
  services.openssh = {
    enable = true;
    settings = {
      AllowUsers = [ "mani" ];
      PermitRootLogin = "no";
      PasswordAuthentication = true; # Temporary until mani has an authorized key.
      KbdInteractiveAuthentication = false;
    };
  };

  services.tailscale.enable = true;

  services.netbird = {
    ui.enable = false;
    clients.default = {
      name = "netbird";
      interface = "wt0";
      port = 51820;
      dir.state = "/var/lib/netbird";
      hardened = true;

      # The daemon runs as netbird, so use OpenSSH rather than NetBird's
      # embedded server, which would need to switch into local accounts.
      config = {
        ServerSSHAllowed = false;
        EnableSSHRoot = false;
        EnableSSHSFTP = false;
        EnableSSHLocalPortForwarding = false;
        EnableSSHRemotePortForwarding = false;
        DisableSSHAuth = false;
      };
    };
  };

  # systemd-resolved integrates both overlay clients without openresolv's
  # conflicting DNS forwarding. NixOS also configures NetworkManager to use it.
  services.resolved.enable = true;

  # NetBird policies are the access-control boundary for traffic arriving on
  # the overlay. Any service listening on wt0 is reachable when policy allows.
  networking.firewall.trustedInterfaces = [ "wt0" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
