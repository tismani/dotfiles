{ config, pkgs, ... }:

{
  # Recent kernel for AMD hardware stability and the amdxdna NPU driver.
  # nix-amd-ai requires kernel >= 6.14 when the NPU is enabled.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Raise the amdgpu GTT ceiling so large models fit in unified memory. The
  # TTM pages_limit / page_pool sizing is handled declaratively below via
  # hardware.amd-npu.gpuMemory (replaces the old amdttm.* kernel params).
  boot.kernelParams = [
    "amdgpu.gttsize=117760" # ~115 GB GTT pool
  ];

  # AMD AI inference stack from nix-amd-ai: a natively-packaged Lemonade
  # server (OpenAI-compatible) with ROCm GPU + XDNA-2 NPU backends. Replaces
  # both the old lemonade-server podman container and the Vulkan ollama setup.
  # https://github.com/noamsto/nix-amd-ai
  hardware.amd-npu = {
    enable = true;
    enableNPU = true; # Strix Halo XDNA-2 NPU
    enableFastFlowLM = true; # NPU-accelerated LLM runtime
    enableLemonade = true; # OpenAI-compatible lemond server
    enableROCm = true; # ROCm GPU backend for llama.cpp / stable-diffusion

    gpuTarget = "gfx1151"; # Strix Halo iGPU

    lemonade = {
      user = "mani";
      host = "0.0.0.0"; # reachable on the LAN (default: localhost)
      # port defaults to 13305

      # Lemonade >= 11.5.0 validates the browser's Origin header and answers
      # 403 "Origin not allowed" for anything non-loopback, so reaching the web
      # UI over the LAN needs the origin listed here. Loopback and desktop
      # schemes (tauri://, file://) are always allowed, so this is only for
      # browsers on other machines. Env-only upstream — no config.json key, so
      # `lemonade.settings` cannot carry it.
      allowedOrigins = [
        "http://10.1.3.246:13305" # halo on the LAN
        "http://halo:13305"
      ];

      # Force full GPU offload rather than relying on llama.cpp's `-ngl auto`
      # fit heuristic. Belt-and-braces: the actual cause of this host running
      # everything on the CPU was NOT the fit heuristic but a stale
      # ~/.cache/lemonade/bin/therock ROCm 7.13 runtime (downloaded 2026-07-19
      # by a pre-#57 lemonade) that lemond prepends to LD_LIBRARY_PATH, where
      # it shadows the nix llama-server's own ROCm 7.2.3 libs and leaves it
      # with zero visible devices ("no usable GPU found, --gpu-layers option
      # will be ignored"). nix-amd-ai patches will_install_therock() to false
      # so it's never re-fetched, but nothing removes a dir that already
      # exists — see the note below.
      #
      # Overrides (not extends) the module's flashAttn-generated `args`, hence
      # --flash-attn is repeated here. Note this bypasses the fit check: a model
      # too large for the GTT pool will now OOM rather than fall back to CPU.
      # With two models pinned (~92 GiB of the 112 GiB pool) that margin is
      # thin — drop back to `auto` if a third model is ever added.
      settings = {
        llamacpp.args = "--flash-attn on -ngl 99";

        # Keep both preloaded models resident instead of evicting one to load
        # the other: gpt-oss-120b (58.5 GiB + ~4.8 GiB KV — only 18 of its 36
        # layers use full attention, the rest a 128-token sliding window) plus
        # Qwen3.6-35B-A3B (21.3 GiB + ~5 GiB KV) is ~91 GiB against the 112 GiB
        # TTM pool below. Leave headroom when adding a third.
        max_loaded_models = -1;
      };
    };

    # Strix Halo / 128 GB unified-memory tuning. Emitted as the ttm
    # pages_limit + page_pool_size modprobe options.
    gpuMemory = {
      ttmSizeGiB = 112;
      pagePoolSizeGiB = 112;
    };
  };

  # Preload both chat models into lemonade right after lemond (re)starts, so
  # they're already resident by the time open-webui or an agent connects
  # instead of eating the first request's latency. Both are pinned and
  # max_loaded_models is -1, so neither evicts the other.
  #
  # gpt-oss-120b is the agent model: measured on this host at 588 t/s prefill
  # @16k and 54 t/s decode, vs Qwen's 945 / 51 (llama-bench, -ngl 99 -fa 1).
  # It decodes as fast despite 3.3x the parameters; Qwen stays as the
  # low-latency model for short open-webui questions, where its ~1000 t/s
  # prefill is the difference that shows.
  #
  # ExecStartPost blocks lemond's transition to "active" until this finishes,
  # so TimeoutStartSec has to cover a cold load of both GGUFs (~80 GB off
  # NVMe) rather than just one.
  systemd.services.lemond.serviceConfig = {
    TimeoutStartSec = "900s";
    ExecStartPost = [
      (toString (pkgs.writeShellScript "lemonade-preload" ''
        set -euo pipefail
        port="${toString config.hardware.amd-npu.lemonade.port}"
        base="http://127.0.0.1:$port"
        until ${pkgs.curl}/bin/curl -fs "$base/api/v1/health" >/dev/null; do
          sleep 1
        done
        # A preload is an optimization, not a precondition: don't let a model
        # that fails to load (bad download, GTT pressure) take the whole
        # service down with it — lemond still serves everything else.
        for model in "gpt-oss-120b-GGUF" "Qwen3.6-35B-A3B-MTP-GGUF"; do
          ${pkgs.lemonade}/bin/lemonade --host 127.0.0.1 --port "$port" \
            load "$model" --pinned \
            || echo "lemonade-preload: failed to load $model, continuing" >&2
        done
      ''))
    ];
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    environment = {
      # Point open-webui at lemonade's OpenAI-compatible endpoint.
      OPENAI_API_BASE_URL = "http://127.0.0.1:13305/api/v1";
      # Ollama has been removed in favour of lemonade.
      ENABLE_OLLAMA_API = "False";

      # Kokoro TTS via lemonade's OpenAI-compatible audio/speech endpoint.
      AUDIO_TTS_ENGINE = "openai";
      AUDIO_TTS_OPENAI_API_BASE_URL = "http://127.0.0.1:13305/api/v1";
      AUDIO_TTS_OPENAI_API_KEY = "lemonade"; # ignored by lemonade, must be non-empty
      AUDIO_TTS_MODEL = "kokoro-v1";
      AUDIO_TTS_VOICE = "af_bella";

      # Speech-to-text: built-in faster-whisper running locally.
      # NOTE: mic capture in the browser needs a secure context (HTTPS or localhost)
      AUDIO_STT_ENGINE = ""; # empty = local whisper
      WHISPER_MODEL = "medium.en";

      # Web search via the local SearXNG instance defined below.
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://127.0.0.1:8888/search?q=<query>";

      # RAG / document chat: local sentence-transformers embeddings, no external service required.
      RAG_EMBEDDING_ENGINE = ""; # empty = local sentence-transformers
      RAG_EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2";
      ENABLE_RAG_HYBRID_SEARCH = "True"; # Hybrid search adds a reranker for quality.
    };
  };

  # SearXNG: local, loopback-only metasearch backing open-webui web search.
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    settings = {
      server = {
        port = 8888;
        bind_address = "127.0.0.1";
        secret_key = "3U7GHWo1ruE0dz6kVqIxqVo+J65X1uG68NYdnlQ0VNg=";
        limiter = false; # allow open-webui's automated queries
      };
      # open-webui consumes results as JSON, which searxng disables by default.
      search.formats = [ "html" "json" ];
    };
  };

  # Lemonade server (13305) and LM Studio (1234).
  networking.firewall.allowedTCPPorts = [ 1234 13305 ];

  # Diagnostics / GUI tooling. The Vulkan/ROCm runtimes are wired by the
  # amd-npu module, so only keep the inspection tools and LM Studio here.
  environment.systemPackages = with pkgs; [
    amdgpu_top
    vulkan-tools
    lmstudio
  ];
}
