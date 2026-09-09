{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.file.".omp/agent/models.yml".text = ''
    providers:
      halo:
        baseUrl: http://halo:4000/v1
        api: openai-completions
        apiKey: "!security find-generic-password -w -s litellm-halo"
        auth: apiKey
        authHeader: true
        discovery:
          type: litellm
          timeoutMs: 10000
  '';
}
