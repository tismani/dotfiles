{ config, lib, pkgs, ... }:

let
  # Every credential is a sops secret, decrypted to /run/secrets (root 0400).
  # nixflix reads `_secret` files at runtime as root (LoadCredential / "+"
  # ExecStartPre), so values never land in the world-readable Nix store.
  secret = name: { _secret = config.sops.secrets.${name}.path; };

  # <name>.home.lan -> local port, served by Caddy on :80. Each name also
  # needs a router DNS entry (no wildcard support) pointing at ajwa.
  # VPN-confined services (qBittorrent, SABnzbd) aren't on 127.0.0.1; they'd
  # need their namespace address instead.
  proxied = {
    requests = 5055; # Seerr
  };
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
      "seerr/api_key" = { };
      "indexers/ninjacentral/api_key" = { };
      "indexers/bwtorrents/username" = { };
      "indexers/bwtorrents/password" = { };
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
      # Who may reach the confined web UIs (qBittorrent, SABnzbd): LAN,
      # 192.168.100.x, and Tailscale (IPv4 CGNAT + IPv6 ULA; MagicDNS names
      # resolve to both).
      accessibleFrom = [
        "10.0.0.0/8"
        "192.168.100.0/24"
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
      config = {
        apiKey = secret "prowlarr/api_key";
        hostConfig.username = secret "prowlarr/username";
        hostConfig.password = secret "prowlarr/password";
        # `name` must match the indexer's name in Prowlarr's catalogue exactly
        # (Indexers > Add Indexer), or the rebuild fails with "No schema
        # found". Credentials go in sops; declare each one in sops.secrets.
        indexers = [
          { name = "NinjaCentral"; apiKey = secret "indexers/ninjacentral/api_key"; }
          { name = "BwTorrents"; username = secret "indexers/bwtorrents/username"; password = secret "indexers/bwtorrents/password"; }
          # { name = "The Pirate Bay"; }  # public: no credentials
        ];
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
      # Cap downloads at 200 Mbps of the 300 Mbps line. KiB/s; set here, not
      # in the WebUI, since qBittorrent.conf is rewritten on every start.
      serverConfig.BitTorrent.Session.GlobalDLSpeedLimit = 200 * 1000 * 1000 / 8 / 1024;
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
      # 200 of 300 Mbps: bandwidth_perc only throttles relative to
      # bandwidth_max (the line speed, 300 Mbps ≈ 36 MiB/s).
      settings.misc.bandwidth_max = "36M";
      settings.misc.bandwidth_perc = 67;
      # Credentials go in sops like the rest:
      settings.servers = [{
        name = "newshosting";
        host = "news.newshosting.com";
        username = secret "usenet/newshosting/username";
        password = secret "usenet/newshosting/password";
      }];
    };

    # TRaSH Guides quality profiles + custom formats, synced daily.
    recyclarr = {
      enable = true;
      radarrQuality = "4K"; # "[SQP] SQP-1 (2160p)"
      sonarrQuality = "1080p"; # "WEB-1080p (Alternative)"
    };

    # Rule-based cleanup on :6246. Talks to Jellyfin/Seerr/Radarr/Sonarr
    # with their existing sops API keys (nixflix defaults).
    maintainerr = {
      enable = true;
      openFirewall = true;
      # Source of truth: groups not listed here are deleted on each sync, and
      # UI edits are overwritten. To change one, draft it in the UI, export
      # with `curl localhost:6246/api/rules`, and port it here (see nixflix
      # docs: examples/maintainerr-rules). firstVal [ 6 0 ] = Jellyfin "date
      # added"; customVal is seconds ago. arrAction defaults to DO_NOTHING in
      # the option (not DELETE as the docs table says), so always set it.
      rules = [
        {
          name = "Delete series after 90 days";
          library = "Shows";
          dataType = "season";
          sonarrServerName = "Sonarr";
          arrAction = "DELETE";
          collection.deleteAfterDays = 2;
          rules = [{
            # Added more than 90 days ago.
            customVal = { ruleTypeId = 0; value = toString (90 * 86400); };
            firstVal = [ 6 0 ];
            action = "BEFORE";
            section = 0;
          }];
        }
        {
          name = "delete movies after 45 days";
          library = "Movies";
          dataType = "movie";
          radarrServerName = "Radarr";
          arrAction = "DELETE";
          collection.deleteAfterDays = 5;
          rules = [{
            # Added more than 45 days ago.
            customVal = { ruleTypeId = 0; value = toString (45 * 86400); };
            firstVal = [ 6 0 ];
            action = "BEFORE";
            section = 0;
          }];
        }
      ];
    };

    # Media requests on :5055; logs in with the Jellyfin admin from sops.
    seerr = {
      enable = true;
      openFirewall = true;
      apiKey = secret "seerr/api_key";
      # Defining these replaces nixflix's auto-generated instances (an option
      # default, not merged), so restate the API key and default flag. Profiles
      # point at Recyclarr's instead of the stock HD-1080p.
      radarr.Radarr = {
        apiKey = secret "radarr/api_key";
        isDefault = true;
        activeProfileName = "[SQP] SQP-1 (2160p)";
      };
      sonarr.Sonarr = {
        apiKey = secret "sonarr/api_key";
        isDefault = true;
        activeProfileName = "WEB-1080p (Alternative)";
      };
    };
  };

  # Own Caddy instead of nixflix.caddy: enabling that binds the *arr apps,
  # Seerr and Maintainerr to 127.0.0.1, breaking IP:port access.
  services.caddy = {
    enable = true;
    virtualHosts = lib.mapAttrs' (name: port:
      lib.nameValuePair "http://${name}.home.lan" {
        extraConfig = "reverse_proxy 127.0.0.1:${toString port}";
      }) proxied;
  };
  networking.firewall.allowedTCPPorts = [ 80 ];

  # Plex isn't a nixflix service; it reads the same libraries as Jellyfin.
  # Claim it at http://192.168.100.171:32400/web from the LAN (Plex only allows
  # claiming from the local network), then add /data/media/{movies,tv}.
  services.plex = {
    enable = true;
    openFirewall = true;
    dataDir = "/data/.state/plex";
  };
  # nixflix makes the media dirs root:media 0775; plex needs to read them.
  users.users.plex.extraGroups = [ "media" ];

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
