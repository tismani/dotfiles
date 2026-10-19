{ config, lib, pkgs, ... }:

let
  # Every credential is a sops secret, decrypted to /run/secrets (root 0400).
  # nixflix reads `_secret` files at runtime as root (LoadCredential / "+"
  # ExecStartPre), so values never land in the world-readable Nix store.
  secret = name: { _secret = config.sops.secrets.${name}.path; };
in
{
  sops = {
    defaultSopsFile = ../../secrets/ajwa.yaml;
    secrets = {
      "prowlarr/api_key" = { };
      "prowlarr/username" = { };
      "prowlarr/password" = { };
      "sonarr/api_key" = { };
      "sonarr/username" = { };
      "sonarr/password" = { };
      "radarr/api_key" = { };
      "radarr/username" = { };
      "radarr/password" = { };
      "jellyfin/api_key" = { };
      "jellyfin/admin_password" = { };
      "qbittorrent/username" = { };
      "qbittorrent/password" = { };
      "qbittorrent/password_hash" = { };
      "sabnzbd/api_key" = { };
      "sabnzbd/nzb_key" = { };
      "usenet/newshosting/username" = { };
      "usenet/newshosting/password" = { };
      "wireguard/conf" = { };
    };
  };

  nixflix = {
    enable = true;
    # Created by nixflix's tmpfiles rules (state root 0755, media/downloads
    # root:media 0775); no manual mkdir/chown needed.
    mediaDir = "/data/media";
    stateDir = "/data/.state";
    mediaUsers = [ "mani" ];

    # WireGuard in its own network namespace ("wg"). Confined services' only
    # route out is the tunnel, so a dropped VPN means no traffic, not a leak.
    # Only the download clients are confined (they follow nixflix.vpn.enable
    # by default); the *arr apps use the normal connection. nixflix requires
    # Prowlarr/Sonarr/Radarr to be confined together or not at all.
    vpn = {
      enable = true;
      wgConfFile = config.sops.secrets."wireguard/conf".path;
      # Who may reach the confined web UIs: LAN + Tailscale's CGNAT range.
      accessibleFrom = [ "10.0.0.0/8" "100.64.0.0/10" ];
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
      config = {
        apiKey = secret "prowlarr/api_key";
        hostConfig.username = secret "prowlarr/username";
        hostConfig.password = secret "prowlarr/password";
      };
    };

    sonarr = {
      enable = true;
      openFirewall = true;
      config = {
        apiKey = secret "sonarr/api_key";
        hostConfig.username = secret "sonarr/username";
        hostConfig.password = secret "sonarr/password";
      };
    };

    radarr = {
      enable = true;
      openFirewall = true;
      config = {
        apiKey = secret "radarr/api_key";
        hostConfig.username = secret "radarr/username";
        hostConfig.password = secret "radarr/password";
      };
    };

    jellyfin = {
      enable = true;
      openFirewall = true;
      apiKey = secret "jellyfin/api_key";
      users.admin = {
        mutable = false;
        policy.isAdministrator = true;
        password = secret "jellyfin/admin_password";
      };
    };

    torrentClients.qbittorrent = {
      enable = true;
      openFirewall = true;
      # Credential the *arr apps use to talk to qBittorrent. qBittorrent's own
      # WebUI login is its PBKDF2 hash, injected from sops below.
      password = secret "qbittorrent/password";
    };

    # nixflix defaults the *arr-side qBittorrent username to
    # serverConfig.Preferences.WebUI.Username, which we leave unset (it would
    # land in the store), so the clients were created with a blank username
    # and the *arr connection test failed with HTTP 400.
    downloadarr.qbittorrent.username = secret "qbittorrent/username";

    usenetClients.sabnzbd = {
      enable = true;
      openFirewall = true;
      settings.misc.api_key = secret "sabnzbd/api_key";
      settings.misc.nzb_key = secret "sabnzbd/nzb_key";
      # Credentials go in sops like the rest:
      settings.servers = [{
        name = "newshosting";
        host = "news.newshosting.com";
        username = secret "usenet/newshosting/username";
        password = secret "usenet/newshosting/password";
      }];
    };
  };

  # nixpkgs reinstalls qBittorrent.conf from serverConfig on every start,
  # wiping a password set in the WebUI. Putting Password_PBKDF2 in
  # serverConfig would put the hash in the store, so splice it in from sops
  # after that install (mkAfter orders it last; "+" runs as root to read the
  # secret). `cat >` keeps the file's qbittorrent ownership.
  systemd.services.qbittorrent.serviceConfig.ExecStartPre = lib.mkAfter [
    ("+" + pkgs.writeShellScript "qbittorrent-webui-password" ''
      set -euo pipefail
      conf="${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf"
      # Accept the hash bare or wrapped in @ByteArray(...)/quotes.
      hash="$(tr -d '\n"' < ${config.sops.secrets."qbittorrent/password_hash".path})"
      hash="''${hash#@ByteArray(}"; hash="''${hash%)}"
      line="WebUI\\Password_PBKDF2=\"@ByteArray($hash)\""
      tmp="$(mktemp)"
      # Via ENVIRON, not -v: awk -v would eat the backslash in WebUI\Password.
      LINE="$line" ${pkgs.gawk}/bin/awk '
        /^WebUI\\Password_PBKDF2=/ { next }
        { print }
        /^\[Preferences\]$/ { print ENVIRON["LINE"]; done = 1 }
        END { if (!done) { print "[Preferences]"; print ENVIRON["LINE"] } }
      ' "$conf" > "$tmp"
      cat "$tmp" > "$conf"
      rm -f "$tmp"
    '')
  ];
}
