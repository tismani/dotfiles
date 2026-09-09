{ pkgs, lib, ... }:

let
  modelsDir = "/var/lib/llm-models";
  llamaServer = "${pkgs.llama-cpp-rocm}/bin/llama-server";

  commonArgs = ''
    --host 127.0.0.1 --port ''${PORT}
    --n-gpu-layers 999 --flash-attn on --no-mmap --jinja
    --ctx-size 131072 --parallel 1
    --threads 16 --batch-size 2048 --ubatch-size 512
  '';

  llamaSwapConfig = (pkgs.formats.yaml { }).generate "llama-swap.yaml" {
    healthCheckTimeout = 600;
    logLevel = "info";
    logToStdout = "both";
    sendLoadingState = true;
    globalTTL = 0;

    models = {
      "qwen3.8-27b" = {
        name = "Qwen 3.8 27B (UD-Q4_K_XL)";
        cmd = ''
          ${llamaServer} ${commonArgs}
          --model ${modelsDir}/qwen3.8-27b/Qwen3.8-27B-UD-Q4_K_XL.gguf
          --alias qwen3.8-27b
        '';
        ttl = 0;
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 131072;
        };
      };

      "qwen3.6-35b-a3b" = {
        name = "Qwen 3.6 35B-A3B (UD-Q4_K_XL)";
        cmd = ''
          ${llamaServer} ${commonArgs}
          --model ${modelsDir}/qwen3.6-35b-a3b/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
          --alias qwen3.6-35b-a3b
        '';
        ttl = 0;
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 131072;
        };
      };

      "muse-glimmer-30b" = {
        name = "Muse Glimmer 30B (Dynamic Q4_K_XL + DFlash)";
        cmd = ''
          ${llamaServer} ${commonArgs}
          --model ${modelsDir}/muse-glimmer-30b/Muse-Glimmer-30B-KQuant-Dynamic-Q4_K_XL.gguf
          --mmproj ${modelsDir}/muse-glimmer-30b/mmproj-Muse-Glimmer-30B-Q4_K_M.gguf
          --model-draft ${modelsDir}/muse-glimmer-30b/dflash-Muse-Glimmer-30B-Q4_K_M.gguf
          --spec-type draft-dflash --spec-draft-n-max 4
          --alias muse-glimmer-30b
        '';
        ttl = 0;
        capabilities = {
          "in" = [ "text" "image" ];
          out = [ "text" ];
          tools = true;
          context = 131072;
        };
      };
    };

    # Subset semantics start models only when requested. Once started, every
    # combination is allowed and ttl=0 keeps it resident.
    routing.router = {
      use = "matrix";
      settings.matrix = {
        vars = {
          q38 = "qwen3.8-27b";
          q36 = "qwen3.6-35b-a3b";
          muse = "muse-glimmer-30b";
        };
        sets.primary = "q38 & q36 & muse";
      };
    };
  };

  primaryModel = name: {
    model_name = name;
    litellm_params = {
      model = "openai/${name}";
      api_base = "http://127.0.0.1:9292/v1";
      api_key = "none";
      timeout = 600;
    };
    model_info = {
      mode = "chat";
      max_input_tokens = 131072;
      max_output_tokens = 32768;
    };
  };

  lemonadeModel = name: {
    model_name = "${name}-lemonade";
    litellm_params = {
      model = "openai/extra.${name}";
      api_base = "http://127.0.0.1:13305/api/v1";
      api_key = "lemonade";
      timeout = 600;
    };
    model_info = {
      mode = "chat";
      max_input_tokens = 131072;
      max_output_tokens = 32768;
    };
  };

  modelPull = pkgs.writeShellApplication {
    name = "llm-model-pull";
    runtimeInputs = [ pkgs.coreutils pkgs.curl ];
    text = ''
      set -euo pipefail

      root=${lib.escapeShellArg modelsDir}

      fetch() {
        repo="$1"
        file="$2"
        dest="$3"
        mkdir -p "$root/$dest"
        echo "Downloading $repo/$file"
        curl --fail --location --retry 5 --continue-at - \
          --output "$root/$dest/$file" \
          "https://huggingface.co/$repo/resolve/main/$file?download=true"
      }

      pull_qwen38() {
        fetch "unsloth/Qwen3.8-27B-GGUF" \
          "Qwen3.8-27B-UD-Q4_K_XL.gguf" "qwen3.8-27b"
      }

      pull_qwen36() {
        fetch "unsloth/Qwen3.6-35B-A3B-GGUF" \
          "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" "qwen3.6-35b-a3b"
      }

      pull_muse() {
        repo="meta-models/Muse-Glimmer-30B-GGUF"
        fetch "$repo" "Muse-Glimmer-30B-KQuant-Dynamic-Q4_K_XL.gguf" \
          "muse-glimmer-30b"
        fetch "$repo" "mmproj-Muse-Glimmer-30B-Q4_K_M.gguf" \
          "muse-glimmer-30b"
        fetch "$repo" "dflash-Muse-Glimmer-30B-Q4_K_M.gguf" \
          "muse-glimmer-30b"
      }

      case "''${1:-all}" in
        qwen3.8-27b) pull_qwen38 ;;
        qwen3.6-35b-a3b) pull_qwen36 ;;
        muse-glimmer-30b) pull_muse ;;
        all) pull_qwen38; pull_qwen36; pull_muse ;;
        *)
          echo "usage: llm-model-pull [all|qwen3.8-27b|qwen3.6-35b-a3b|muse-glimmer-30b]" >&2
          exit 2
          ;;
      esac
    '';
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
      host = "127.0.0.1";
      settings = {
        extra_models_dir = modelsDir;
        ctx_size = 131072;
        max_loaded_models = 1;
        llamacpp.args = "--flash-attn on -ngl 999 --no-mmap --jinja -np 1 -b 2048 -ub 512";
      };
    };

    gpuMemory = {
      ttmSizeGiB = 112;
      pagePoolSizeGiB = 112;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${modelsDir} 0750 mani users - -"
  ];

  systemd.services.llama-swap = {
    description = "On-demand concurrent llama.cpp model router";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "mani";
      Group = "users";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${lib.getExe pkgs.llama-swap} --config ${llamaSwapConfig} --listen 127.0.0.1:9292";
      Restart = "on-failure";
      RestartSec = 5;
      LimitMEMLOCK = "infinity";
      StateDirectory = "llama-swap";
    };
    environment = {
      HSA_ENABLE_SDMA = "0";
      HIP_VISIBLE_DEVICES = "0";
    };
  };

  services.litellm = {
    enable = true;
    host = "0.0.0.0";
    port = 4000;
    environmentFile = "/var/lib/secrets/litellm.env";
    settings = {
      model_list =
        map primaryModel [
          "qwen3.8-27b"
          "qwen3.6-35b-a3b"
          "muse-glimmer-30b"
        ]
        ++ map lemonadeModel [
          "qwen3.8-27b"
          "qwen3.6-35b-a3b"
          "muse-glimmer-30b"
        ];
      general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";
      litellm_settings = {
        drop_params = true;
        request_timeout = 600;
        num_retries = 0;
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 4000 ];

  environment.systemPackages = with pkgs; [
    amdgpu_top
    vulkan-tools
    lmstudio
    llama-swap
    modelPull
  ];
}
