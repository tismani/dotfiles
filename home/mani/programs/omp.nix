{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  # Through Caddy over Tailscale (hosts/halo/caddy.nix): works on and off the
  # LAN, over HTTPS. Needs Tailscale up on this Mac.
  home.file.".omp/agent/models.yml".text = ''
    providers:
      halo:
        baseUrl: https://llm.halo.tismani.com/v1
        api: openai-completions
        auth: none
        discovery:
          type: openai-models-list
          timeoutMs: 10000
  '';
}
