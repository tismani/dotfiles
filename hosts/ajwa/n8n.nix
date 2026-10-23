{ config, pkgs, ... }:

let
  docker = "${config.virtualisation.docker.package}/bin/docker";
  # Containers tracking :latest, updated on every rebuild (see below).
  latest = [ "n8n" "stirling-pdf" ];
in
{
  # n8n in Docker, not services.n8n: nixpkgs ships 2.39.6, but the data was
  # migrated from a 2.44.6 instance and n8n can't downgrade its database
  # (DB migrations are one-way; :latest only ever moves forward).
  virtualisation.oci-containers = {
    backend = "docker";

    containers.n8n = {
      image = "docker.io/n8nio/n8n:latest";
      ports = [ "5678:5678" ];
      # SQLite DB + `config` (holds the encryption key for credentials) live
      # here, copied from the old Unraid appdata. Never in the repo.
      volumes = [ "/data/.state/n8n:/home/node/.n8n" ];
      environment = {
        GENERIC_TIMEZONE = "Asia/Riyadh";
        TZ = "Asia/Riyadh";
        # Plain HTTP on IP:port; a secure cookie would make login fail
        # without HTTPS.
        N8N_SECURE_COOKIE = "false";
        WEBHOOK_URL = "http://192.168.100.171:5678/";
      };
    };

    # PDF tools for n8n workflows, called at http://192.168.100.171:8090
    # (host port; :8080 is SABnzbd's). Not via a shared Docker network:
    # Stirling 3.2.1 answered n8n's container-to-container requests
    # (stirling-pdf:8080) with a 404 redirect page while the same calls
    # through the published port worked.
    containers.stirling-pdf = {
      image = "docker.io/stirlingtools/stirling-pdf:latest";
      ports = [ "8090:8080" ];
      volumes = [
        "/data/.state/stirling-pdf/configs:/configs"
        "/data/.state/stirling-pdf/tessdata:/usr/share/tessdata" # OCR languages
      ];
      environment = {
        TZ = "Asia/Riyadh";
        PUID = "1000";
        PGID = "1000";
        # No login (LAN only, called by n8n without credentials). 3.x turns
        # login on by default (settings.yml security.enableLogin) and ignores
        # the old DOCKER_ENABLE_SECURITY; with login on, n8n's API calls get
        # 401 -> redirect -> 404.
        SECURITY_ENABLELOGIN = "false";
      };
    };
  };

  # A rebuild alone never updates a :latest container: the unit text doesn't
  # change, so it isn't restarted, and Docker only pulls missing images. So
  # each activation kicks this off (async, so a slow or offline pull can't
  # fail the switch): pull every :latest image and restart only containers
  # whose image actually changed.
  systemd.services.docker-pull-latest = {
    description = "Pull :latest images and restart updated containers";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for c in ${toString latest}; do
        img=$(${docker} inspect -f '{{.Config.Image}}' "$c" 2>/dev/null) || continue
        running=$(${docker} inspect -f '{{.Image}}' "$c")
        ${docker} pull -q "$img" >/dev/null || { echo "pull failed: $img"; continue; }
        if [ "$running" != "$(${docker} image inspect -f '{{.Id}}' "$img")" ]; then
          echo "updating $c ($img)"
          systemctl restart "docker-$c.service"
        fi
      done
    '';
  };
  system.activationScripts.docker-pull-latest =
    "${pkgs.systemd}/bin/systemctl --no-block start docker-pull-latest.service || true";

  # Both images run as uid/gid 1000 (n8n's `node`; Stirling via PUID/PGID).
  systemd.tmpfiles.rules = [
    "d /data/.state/n8n 0750 1000 1000 -"
    "d /data/.state/stirling-pdf 0750 1000 1000 -"
    "d /data/.state/stirling-pdf/configs 0750 1000 1000 -"
    "d /data/.state/stirling-pdf/tessdata 0750 1000 1000 -"
  ];

  networking.firewall.allowedTCPPorts = [ 5678 8090 ];
}
