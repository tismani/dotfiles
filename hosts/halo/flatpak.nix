{ pkgs, ... }:

{
  services.flatpak.enable = true;

  # NixOS doesn't manage flatpak remotes/apps declaratively;
  # add Flathub and install apps on boot so it's reproducible via rebuild-halo
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
    '';
  };

  # GUI app store for browsing/installing Flathub apps in GNOME
  environment.systemPackages = [ pkgs.gnome-software ];
}
