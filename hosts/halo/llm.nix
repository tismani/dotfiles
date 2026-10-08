{ pkgs, lib, inputs, ... }:

let
  modelCache = "/home/mani/.cache/huggingface/hub";
  qwen36Dir = "${modelCache}/models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF/snapshots/5bc3e238d916f48a861bac2f8a1990a0e9b7e98d";
  qwen38Dir = "${modelCache}/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502";
  qwen38TurboDir = "${modelCache}/models--DavidAU--Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF/snapshots/ceb55042229d17dcf45df52ad84698339e63d4c5";
  qwen38DFlashDir = "${modelCache}/models--z-lab--Qwen3.8-27B-DFlash2-GGUF/snapshots/2d9571f8ce46e151f61c6499c99dee6079e1d610";
  qwen38FlashNextDir = "${modelCache}/models--unsloth--Qwen3.8-Flash-Next-GGUF/snapshots/38bb39ee97821de2c9009abb7e93950eec396e66";
  deepseekV4Dir = "${modelCache}/models--antirez--deepseek-v4-gguf/snapshots/1cd7b564460821938add0475a60b942c409295e0";
  deepseekV4DSparkDir = "${modelCache}/models--antirez--deepseek-v4-gguf/snapshots/e7f04037032990db0346398d249baf9fb9df1ccc";
  qwen3AsrDir = "${modelCache}/models--Qwen--Qwen3-ASR-1.7B/snapshots/7278e1e70fe206f11671096ffdd38061171dd6e5";
  qwen3TtsBaseDir = "${modelCache}/models--Qwen--Qwen3-TTS-12Hz-1.7B-Base/snapshots/fd4b254389122332181a7c3db7f27e918eec64e3";
  qwen3TtsCustomVoiceDir = "${modelCache}/models--Qwen--Qwen3-TTS-12Hz-1.7B-CustomVoice/snapshots/0c0e3051f131929182e2c023b9537f8b1c68adfe";
  qwen3TtsVoiceDesignDir = "${modelCache}/models--Qwen--Qwen3-TTS-12Hz-1.7B-VoiceDesign/snapshots/5ecdb67327fd37bb2e042aab12ff7391903235d3";
  qwenImage21Dir = "${modelCache}/models--Qwen--Qwen-Image-2.1/snapshots/b3179ad355be050328e483a9dfdd9e60cd62adfa";
  minimaxH3Dir = "${modelCache}/models--MiniMaxAI--MiniMax-H3/snapshots/42ed227ee7df40d41602854ae760620d6eb651fe";
  nemotronDir = "${modelCache}/models--unsloth--NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF/snapshots/f2d3fe3694501008786e81e5f20360cbf715496a";
  gemmaDir = "${modelCache}/models--unsloth--gemma-4-26B-A4B-it-GGUF/snapshots/c099eb48e663fd284577b04978a94ffccb261841";
  qwen3EmbeddingDir = "${modelCache}/models--Qwen--Qwen3-Embedding-4B-GGUF/snapshots/f4602530db1d980e16da9d7d3a70294cf5c190be";
  flux2Dir = "${modelCache}/models--city96--FLUX.2-dev-gguf/snapshots/ade5d688ddab0d9cf4a5b01bf4321e01c115020d";
  flux2VaeDir = "${modelCache}/models--Comfy-Org--flux2-dev/snapshots/ed33133cd56476eac818c0943b6f9419b3e4a3a1";
  mistralSmall32Dir = "${modelCache}/models--unsloth--Mistral-Small-3.2-24B-Instruct-2506-GGUF/snapshots/b750ec2299225e492f1bd27cab88a0a595fa848f";

  gufoPackage = inputs.gufo.packages.x86_64-linux.default;
  gufo = lib.getExe gufoPackage;
  llamaServer = "${pkgs.llama-cpp-rocm}/bin/llama-server";
  sdServer = "${pkgs.stable-diffusion-cpp-vulkan}/bin/sd-server";
  commonArgs = ''
    --host 127.0.0.1 --port ''${PORT}
    --device ROCm0 --n-gpu-layers all
    --flash-attn on
    --cache-type-k q8_0 --cache-type-v q8_0
    --parallel 1
    --batch-size 2048 --ubatch-size 512
    --threads 16 --threads-batch 16
    --load-mode dio
    --fit off --jinja --metrics
  '';
  qwenYarnArgs = "--rope-scaling yarn --rope-scale 4 --yarn-orig-ctx 262144";

  unloadLemonadeModels = pkgs.writeShellScript "unload-lemonade-models" ''
    attempts=0
    until ${pkgs.lemonade}/bin/lemonade status >/dev/null 2>&1; do
      attempts=$((attempts + 1))
      if [ "$attempts" -ge 60 ]; then
        echo "lemond did not become ready within 60 seconds" >&2
        exit 1
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done

    exec ${pkgs.lemonade}/bin/lemonade unload
  '';

  llamaSwapConfig = (pkgs.formats.yaml { }).generate "llama-swap.yaml" {
    # Direct I/O plus million-token KV allocation can take several minutes.
    healthCheckTimeout = 1800;
    logLevel = "info";
    logToStdout = "both";
    sendLoadingState = true;

    models = {
      "Qwen3.6-35B-A3B-MTP-GGUF" = {
        cmd = ''
          ${llamaServer}
          ${commonArgs}
          --ctx-size 262144
          ${qwenYarnArgs}
          --model ${qwen36Dir}/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
          --mmproj ${qwen36Dir}/mmproj-F16.gguf
          --alias Qwen3.6-35B-A3B-MTP-GGUF
          --spec-type draft-mtp --spec-draft-n-max 2
        '';
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 1010000;
        };
      };

      "Qwen3.8-27B-GGUF" = {
        cmd = ''
          ${llamaServer}
          ${commonArgs}
          --ctx-size 262144
          ${qwenYarnArgs}
          --model ${qwen38Dir}/Qwen3.8-27B-UD-Q4_K_XL.gguf
          --mmproj ${qwen38Dir}/mmproj-F16.gguf
          --alias Qwen3.8-27B-GGUF
          --spec-type draft-mtp --spec-draft-n-max 3
        '';
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 1000000;
        };
      };

      # DavidAU's TURBO fine-tune of Qwen3.8 27B (Heretic-uncensored, coder
      # tuned, shorter thinking). Q4_K_M because the card warns tool calling
      # degrades below it. Native 262k context, no YaRN. The card recommends 2
      # MTP draft tokens and temp <= 1 (higher temps hurt MTP acceptance);
      # sampler defaults are its thinking-mode coding preset.
      "Qwen3.8-27B-TURBO-Fable-Cold-Fusion-MTP-GGUF" = {
        cmd = ''
          ${llamaServer}
          ${commonArgs}
          --ctx-size 262144
          --model ${qwen38TurboDir}/Qwen3.8-27B-TurboFCFusion-735-882-Here-Uncen-NEO-CODER-MAX-MTP-Q4_K_M.gguf
          --mmproj ${qwen38TurboDir}/mmproj-F16.gguf
          --alias Qwen3.8-27B-TURBO-Fable-Cold-Fusion-MTP-GGUF
          --spec-type draft-mtp --spec-draft-n-max 2
          --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0.0
        '';
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 262144;
        };
      };

      "gufo/Qwen3.8-27B-DFlash2" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT} --sessions 1
          llm
          --model ${qwen38Dir}/Qwen3.8-27B-UD-Q4_K_XL.gguf
          --mmproj ${qwen38Dir}/mmproj-BF16.gguf
          --served-model-name gufo/Qwen3.8-27B-DFlash2
          --context 262144
          --think off
          --temperature 0.8 --top-k 40 --top-p 0.95 --min-p 0.05
          --speculative dflash2
          --dflash-model ${qwen38DFlashDir}/Qwen3.8-27B-DFlash2-Q4_K_M.gguf
          --draft-policy adaptive
        '';
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 262144;
        };
      };

      "gufo/Qwen3.8-Flash-Next-MTP" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT} --sessions 1
          llm
          --model ${qwen38FlashNextDir}/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf
          --mmproj ${qwen38FlashNextDir}/mmproj-BF16.gguf
          --served-model-name gufo/Qwen3.8-Flash-Next-MTP
          --context 131072
          --speculative mtp
          --mtp-model ${qwen38FlashNextDir}/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
        '';
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 131072;
        };
      };

      "gufo/DeepSeek-V4-Flash-DSpark" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT} --sessions 1
          llm
          --model ${deepseekV4Dir}/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf
          --served-model-name gufo/DeepSeek-V4-Flash-DSpark
          --context 262144
          --speculative dspark
          --dspark-model ${deepseekV4DSparkDir}/DeepSeek-V4-Flash-DSpark-support-0731.gguf
        '';
        capabilities = {
          "in" = [ "text" ];
          out = [ "text" ];
          tools = true;
          context = 262144;
        };
      };

      "gufo/Qwen3-ASR-1.7B" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT}
          --max-request-bytes 268435456
          asr
          --model ${qwen3AsrDir}
          --context 1024
          --served-model-name gufo/Qwen3-ASR-1.7B
        '';
        capabilities = {
          "in" = [ "audio" ];
          out = [ "text" ];
          context = 1024;
        };
      };

      "gufo/Qwen3-TTS-12Hz-1.7B-Base" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT}
          --max-request-bytes 268435456
          tts
          --model ${qwen3TtsBaseDir}
          --context 4096
          --served-model-name gufo/Qwen3-TTS-12Hz-1.7B-Base
        '';
        capabilities = {
          "in" = [ "text" "audio" ];
          out = [ "audio" ];
          context = 4096;
        };
      };

      "gufo/Qwen3-TTS-12Hz-1.7B-CustomVoice" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT}
          tts
          --model ${qwen3TtsCustomVoiceDir}
          --context 4096
          --served-model-name gufo/Qwen3-TTS-12Hz-1.7B-CustomVoice
        '';
        capabilities = {
          "in" = [ "text" ];
          out = [ "audio" ];
          context = 4096;
        };
      };

      "gufo/Qwen3-TTS-12Hz-1.7B-VoiceDesign" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT}
          tts
          --model ${qwen3TtsVoiceDesignDir}
          --context 4096
          --served-model-name gufo/Qwen3-TTS-12Hz-1.7B-VoiceDesign
        '';
        capabilities = {
          "in" = [ "text" ];
          out = [ "audio" ];
          context = 4096;
        };
      };

      "gufo/Qwen-Image-2.1" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT}
          --max-request-bytes 268435456
          image
          --model ${qwenImage21Dir}
          --served-model-name gufo/Qwen-Image-2.1
        '';
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "image" ];
          context = 16384;
        };
      };

      # llama-swap does not have a native OpenAI video route yet. Keep this
      # ID slash-free so /upstream/minimax-h3/v1/videos can select it.
      "minimax-h3" = {
        checkEndpoint = "/ready";
        cmd = ''
          ${gufo} serve
          --host 127.0.0.1 --port ''${PORT} --sessions 1
          video
          --model ${minimaxH3Dir}
          --root /var/lib/llama-swap/gufo-h3-jobs
          --ttl 3600
        '';
        # llama-swap v249 cannot express "video" in capabilities.out yet.
        metadata = {
          input_modalities = [ "text" ];
          output_modalities = [ "video" ];
          context = 4096;
        };
      };

      "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF" = {
        cmd = ''
          ${llamaServer}
          ${commonArgs}
          --ctx-size 1048576
          --model ${nemotronDir}/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-UD-Q4_K_XL.gguf
          --alias NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF
          --spec-type draft-mtp --spec-draft-n-max 3
        '';
        capabilities = {
          "in" = [ "text" ];
          out = [ "text" ];
          tools = true;
          context = 1048576;
        };
      };

      "Gemma-4-26B-A4B-it-MTP-GGUF" = {
        cmd = ''
          ${llamaServer}
          ${commonArgs}
          --ctx-size 262144
          --model ${gemmaDir}/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf
          --mmproj ${gemmaDir}/mmproj-F16.gguf
          --alias Gemma-4-26B-A4B-it-MTP-GGUF
          --spec-type draft-mtp --spec-draft-n-max 3
          --model-draft ${gemmaDir}/mtp-gemma-4-26B-A4B-it.gguf
          --device-draft ROCm0 --n-gpu-layers-draft all
          --cache-type-k-draft q4_0 --cache-type-v-draft q4_0
        '';
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 262144;
        };
      };

      # FLUX.2 [dev] (32B flow transformer, non-commercial license) with
      # Mistral Small 3.2 24B as its text encoder. gufo's image backend only
      # serves Qwen Image, so this runs on stable-diffusion.cpp, which has
      # OpenAI /v1/images routes. The official BFL repo is gated and bf16 is
      # ~64 GB + ~48 GB encoder, so this uses the GGUFs sd.cpp's docs point
      # to: city96's Q8_0 transformer, unsloth's Q8_0 Mistral, and Comfy-Org's
      # ungated copy of the VAE. cfg-scale 1 because guidance is distilled;
      # --guidance 4 is the model card's default. Steps are 28, not the
      # card's 50: on Vulkan a 1024x1024 step takes ~32.7 s, so 50 steps took
      # 1645 s, too close to the 1800 s LiteLLM timeout.
      # Vulkan, not ROCm: sd.cpp's ROCm build (master-874) aborts on the first
      # request when most of GTT is free ("model manager cannot make enough
      # memory available ... available 0.00 MB device", then a GGML_ASSERT);
      # --max-vram and --params-backend/--eager-load did not help.
      # --vae-conv-direct cuts Vulkan's VAE decode from ~39 s to ~2 s (SDXL).
      "FLUX.2-dev" = {
        checkEndpoint = "/v1/models";
        cmd = ''
          ${sdServer}
          --listen-ip 127.0.0.1 --listen-port ''${PORT}
          --diffusion-model ${flux2Dir}/flux2-dev-Q8_0.gguf
          --llm ${mistralSmall32Dir}/Mistral-Small-3.2-24B-Instruct-2506-Q8_0.gguf
          --vae ${flux2VaeDir}/split_files/vae/flux2-vae.safetensors
          --backend Vulkan0
          --diffusion-fa --vae-conv-direct
          --width 1024 --height 1024
          --steps 28 --cfg-scale 1.0 --guidance 4.0
          --sampling-method euler
          --seed -1
        '';
        capabilities = {
          "in" = [ "text" ];
          out = [ "image" ];
          context = 512;
        };
      };

      # Open WebUI's RAG embedder. Not commonArgs: those chat flags (--parallel
      # 1, 512-token ubatch, q8 KV) would truncate or serialize batched
      # embedding requests. Non-causal pooling needs each input to fit in one
      # ubatch, so ubatch equals the per-slot context (32768 / 4).
      "Qwen3-Embedding-4B-GGUF" = {
        cmd = ''
          ${llamaServer}
          --host 127.0.0.1 --port ''${PORT}
          --device ROCm0 --n-gpu-layers all
          --flash-attn on
          --embedding --pooling last
          --ctx-size 32768 --parallel 4
          --batch-size 8192 --ubatch-size 8192
          --threads 16 --threads-batch 16
          --model ${qwen3EmbeddingDir}/Qwen3-Embedding-4B-Q8_0.gguf
          --alias Qwen3-Embedding-4B-GGUF
        '';
        # llama-swap v249 cannot express "embedding" in capabilities.out yet.
        metadata = {
          input_modalities = [ "text" ];
          output_modalities = [ "embedding" ];
          context = 8192;
          dimensions = 2560;
        };
      };

    };

    routing.router = {
      use = "matrix";
      settings.matrix = {
        vars = {
          u = "gufo/Qwen3.8-27B-DFlash2";
          uf = "gufo/Qwen3.8-Flash-Next-MTP";
          ud = "gufo/DeepSeek-V4-Flash-DSpark";
          ua = "gufo/Qwen3-ASR-1.7B";
          utb = "gufo/Qwen3-TTS-12Hz-1.7B-Base";
          utc = "gufo/Qwen3-TTS-12Hz-1.7B-CustomVoice";
          utv = "gufo/Qwen3-TTS-12Hz-1.7B-VoiceDesign";
          ui = "gufo/Qwen-Image-2.1";
          f2 = "FLUX.2-dev";
          uv = "minimax-h3";
          q36 = "Qwen3.6-35B-A3B-MTP-GGUF";
          q38 = "Qwen3.8-27B-GGUF";
          qt = "Qwen3.8-27B-TURBO-Fable-Cold-Fusion-MTP-GGUF";
          n = "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF";
          g = "Gemma-4-26B-A4B-it-MTP-GGUF";
          e = "Qwen3-Embedding-4B-GGUF";
        };
        # The embedder (~4.3 GiB Q8 weights plus a small KV cache) may stay
        # resident beside every set except DeepSeek, Flash-Next and H3, the
        # largest footprints, which still run alone. Flash-Next (~107 GB of
        # weights + MTP) left only ~2-3 GiB of host RAM with the embedder
        # beside it and pushed Open WebUI and llama-swap into swap; its context
        # is also capped at 131072 to shrink the KV cache. Subset semantics
        # keep "& e" optional: it is never preloaded. The Gemma + Qwen Image
        # measurement in docs/halo-dual-model-memory.md predates the embedder.
        evict_costs.e = 1;
        sets = {
          "gufo-qwen38" = "u & e";
          "gufo-flash-next" = "uf";
          "gufo-deepseek" = "ud";
          "gufo-asr" = "ua & e";
          "gufo-tts-base" = "utb & e";
          "gufo-tts-custom-voice" = "utc & e";
          "gufo-tts-voice-design" = "utv & e";
          "gufo-image-gemma" = "ui & g & e";
          # ~57 GiB of Q8 weights before compute buffers: too large to sit
          # beside Gemma within the 87 GiB pair budget, so only the embedder.
          "sd-flux2" = "f2 & e";
          "gufo-video" = "uv";
          "gguf-pairs" = "((q36 & q38) | (q36 & n) | (q36 & g) | (q38 & n) | (q38 & g) | (n & g) | (qt & q36) | (qt & q38) | (qt & n) | (qt & g)) & e";
        };
      };
    };
  };
in
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amdgpu.gttsize=117760" ];

  hardware.amd-npu = {
    enable = true;
    enableNPU = true;
    enableFastFlowLM = true;
    enableLemonade = true;
    enableROCm = true;
    gpuTarget = "gfx1151";

    lemonade = {
      user = "mani";
      # Lemonade is not fronted by the remote LiteLLM container. Keep it
      # reachable directly for NPU/TTS diagnostics and recovery.
      host = "0.0.0.0";
      models = [
        "Qwen3.6-35B-A3B-MTP-GGUF"
        "Qwen3.8-27B-GGUF"
        "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF"
        "Gemma-4-26B-A4B-it-MTP-GGUF"
      ];
      settings = {
        ctx_size = 262144;
        max_loaded_models = 1;
        llamacpp.args = "--flash-attn on -ngl 999 --no-mmap -np 1 -b 2048 -ub 512";
      };
    };

    gpuMemory = {
      ttmSizeGiB = 112;
      pagePoolSizeGiB = 112;
    };
  };

  systemd.services.llama-swap = {
    description = "On-demand llama.cpp gateway";
    wantedBy = [ "multi-user.target" ];
    wants = [ "lemond.service" ];
    after = [ "network.target" "lemond.service" ];
    serviceConfig = {
      Type = "simple";
      User = "mani";
      Group = "users";
      SupplementaryGroups = [ "video" "render" ];
      ExecStartPre = unloadLemonadeModels;
      ExecStart = "${lib.getExe pkgs.llama-swap} --config ${llamaSwapConfig} --listen 0.0.0.0:9292";
      Restart = "on-failure";
      RestartSec = 5;
      LimitMEMLOCK = "infinity";
      # Gufo needs a writable runtime directory even when this system service
      # starts before mani has a login session.
      RuntimeDirectory = "llama-swap";
      RuntimeDirectoryMode = "0700";
      StateDirectory = "llama-swap";
    };
    environment = {
      HSA_ENABLE_SDMA = "0";
      HIP_VISIBLE_DEVICES = "0";
      XDG_RUNTIME_DIR = "/run/llama-swap";
    };
  };

  networking.firewall.allowedTCPPorts = [ 9292 13305 ];

  environment.systemPackages = with pkgs; [
    amdgpu_top
    vulkan-tools
    lmstudio
    llama-swap
    gufoPackage
  ];
}
