{ config, pkgs, lib, llamaSwapMetricsModels, ... }:

let
  llamaSwap = "127.0.0.1:9292";
  promPort = 9090;
  nodePort = 9100;
  grafanaPort = 3000;

  # grafana.com "Node Exporter Full" (1860). Pinned by revision and hash; to
  # bump, change rev and set lib.fakeHash, then build to get the new hash.
  nodeExporterFull = pkgs.fetchurl {
    name = "node-exporter-full.json";
    url = "https://grafana.com/api/dashboards/1860/revisions/46/download";
    hash = "sha256-5Y3cXcU11MkB+U2pZIvD49Wue2946Y4YW86LKJlhzqM=";
  };

  dashboards = pkgs.linkFarm "halo-grafana-dashboards" [
    { name = "llm.json"; path = ./grafana/llm.json; }
    { name = "node-exporter-full.json"; path = nodeExporterFull; }
  ];

  grafanaSecret = {
    owner = "grafana";
    restartUnits = [ "grafana.service" ];
  };
in
{
  services.prometheus = {
    enable = true;
    # No auth on Prometheus: loopback only, reached through Grafana.
    listenAddress = "127.0.0.1";
    port = promPort;
    retentionTime = "90d";
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = nodePort;
      # drm: amdgpu busy %, VRAM and GTT (Strix Halo's model memory is GTT).
      # hwmon (default) carries the amdgpu temperature, power and clock.
      enabledCollectors = [ "drm" "systemd" ];
    };

    scrapeConfigs = [
      {
        # llama-swap's own monitor: CPU, RAM, swap, load, network. Its GPU
        # metrics are NVIDIA-only, so the GPU comes from node_exporter.
        job_name = "llama-swap";
        static_configs = [ { targets = [ llamaSwap ]; } ];
      }
      {
        # Per-model llama.cpp metrics through llama-swap's /upstream
        # passthrough. upstream.ignorePaths (./llm.nix) makes an unloaded
        # model answer 409 instead of being swapped in, so up{job="llm"} is
        # also "which models are loaded". The list follows llm.nix's models.
        job_name = "llm";
        static_configs = map (model: {
          targets = [ llamaSwap ];
          labels = {
            inherit model;
            __metrics_path__ = "/upstream/${model}/metrics";
          };
        }) llamaSwapMetricsModels;
      }
      {
        job_name = "lemonade";
        static_configs = [ { targets = [ "127.0.0.1:13305" ]; } ];
      }
      {
        job_name = "node";
        static_configs = [ { targets = [ "127.0.0.1:${toString nodePort}" ]; } ];
      }
    ];
  };

  sops.secrets."grafana/admin_password" = grafanaSecret;
  sops.secrets."grafana/secret_key" = grafanaSecret;

  services.grafana = {
    enable = true;
    settings = {
      server = {
        # Reached through Caddy (./caddy.nix) only.
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = "grafana.halo.tismani.com";
        root_url = "https://grafana.halo.tismani.com/";
      };
      security = {
        admin_user = "admin";
        admin_password = "$__file{${config.sops.secrets."grafana/admin_password".path}}";
        secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
        cookie_secure = true;
      };
      # Shared Tailscale users reach the login page via Caddy; accounts are
      # created by the admin only.
      users.allow_sign_up = false;
      "auth.anonymous".enabled = false;
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
      };
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:${toString promPort}";
            isDefault = true;
            jsonData.timeInterval = "15s";
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "halo";
            # Nix is authoritative: UI edits can't be saved over these; use
            # "Save as" for a scratch copy, then port it to Nix.
            allowUiUpdates = false;
            options.path = dashboards;
          }
        ];
      };
    };
  };
}
