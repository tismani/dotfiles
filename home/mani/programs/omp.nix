{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.file.".omp/agent/models.yml".text = ''
    providers:
      halo:
        baseUrl: http://halo:4000/v1
        api: openai-completions
        apiKey: LITELLM_API_KEY
        authHeader: true
        discovery:
          type: openai-models-list
          timeoutMs: 10000
  '';
}
