{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.file.".omp/agent/models.yml".text = ''
    providers:
      halo:
        baseUrl: http://halo:9292/v1
        api: openai-completions
        auth: none
        authHeader: false
        discovery:
          type: openai-models-list
          timeoutMs: 10000
  '';
}
