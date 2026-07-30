{ pkgs, ... }:

{
  services.flatpak.enable = true;

  # NixOS doesn't manage flatpak remotes/apps declaratively;
  # add Flathub and install apps on boot so it's reproducible via rebuild-halo
  #
  # com.bitwarden.desktop is here rather than in systemPackages because clipboard
  # copy works in Bitwarden's official Flatpak but not in the nixpkgs build, which
  # compiles the desktop_native Rust module (where the clipboard code lives) itself.
  # Note this also fixes the SSH agent socket under ~/.var/app — see ssh.nix.
  systemd.services.flatpak-add-flathub = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      flatpak install --or-update --noninteractive --assumeyes flathub \
        com.vivaldi.Vivaldi \
        com.bitwarden.desktop
    '';
  };

  # GUI app store for browsing/installing Flathub apps in GNOME
  environment.systemPackages = [ pkgs.gnome-software ];
}
