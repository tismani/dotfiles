{ pkgs, ... }:

{
  services.flatpak.enable = true;

  # NixOS doesn't manage flatpak remotes declaratively;
  # add Flathub on boot so `flatpak install` just works
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
