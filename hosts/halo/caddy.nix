{ config, pkgs, lib, ... }:

let
  domain = "halo.tismani.com";

  # <name>.halo.tismani.com -> loopback port. Cloudflare has a
  # *.halo.tismani.com DNS record (DNS only, not proxied) pointing at halo's
  # Tailscale IP (100.76.51.89), so these names only work on the tailnet and
  # for users halo is shared with. What shared users can reach is limited in
  # the Tailscale access policy (autogroup:shared -> halo:443), not here.
  # The backends' own ports stay open too; Caddy is added alongside.
  proxied = {
    chat = 8080; # Open WebUI (./openwebui.nix)
    llm = 9292; # llama-swap, UI at /ui (./llm.nix)
    lemonade = 13305; # Lemonade / lemond (./llm.nix)
    search = 8888; # SearXNG (./openwebui.nix)
  };
in
{
  sops.secrets."cloudflare/api_token" = { };

  # Caddy reads the token from its environment; a sops template keeps it out
  # of the store and the unit file.
  sops.templates."caddy.env" = {
    content = ''
      CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare/api_token"}
    '';
    restartUnits = [ "caddy.service" ];
  };

  services.caddy = {
    enable = true;
    # Stock caddy has no DNS providers; DNS-01 is the only way to get a public
    # cert for a name that resolves to a LAN IP. Bumping the plugin version
    # changes the hash: set lib.fakeHash and build on halo to get the new one.
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-QSiwKqKvSxhksWBF4/MlBOpyXba5xOQ2sRwA0R7399E=";
    };
    environmentFile = config.sops.templates."caddy.env".path;

    # One wildcard cert: a single renewal, and the service names don't show up
    # in public Certificate Transparency logs. Each name is routed by host.
    virtualHosts."*.${domain}".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Check propagation against Cloudflare's resolver, not the LAN's,
        # which may answer for tismani.com differently (or cache NXDOMAIN).
        resolvers 1.1.1.1
      }

      ${lib.concatStrings (lib.mapAttrsToList (name: port: ''
        @${name} host ${name}.${domain}
        handle @${name} {
          reverse_proxy 127.0.0.1:${toString port}
        }
      '') proxied)}
      handle {
        abort
      }
    '';
  };

  # 80 only serves Caddy's HTTP -> HTTPS redirects.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
