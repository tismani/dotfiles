{ pkgs, lib, ... }:

let
  modelCache = "/home/mani/.cache/huggingface/hub";
  qwen36Dir = "${modelCache}/models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF/snapshots/5bc3e238d916f48a861bac2f8a1990a0e9b7e98d";
  qwen38Dir = "${modelCache}/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502";
  nemotronDir = "${modelCache}/models--unsloth--NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF/snapshots/f2d3fe3694501008786e81e5f20360cbf715496a";
  gemmaDir = "${modelCache}/models--unsloth--gemma-4-26B-A4B-it-GGUF/snapshots/c099eb48e663fd284577b04978a94ffccb261841";

  llamaServer = "${pkgs.llama-cpp-rocm}/bin/llama-server";
  podman = "${pkgs.podman}/bin/podman";
  halogenContainer = "llama-swap-halogen-qwen38-flash-next";
  commonArgs = ''
    --host 127.0.0.1 --port ''${PORT}
    --device ROCm0 --n-gpu-layers all
    --flash-attn on
    --cache-type-k q4_0 --cache-type-v q4_0
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
          --ctx-size 1010000
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
          --ctx-size 1000000
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

      "peonist-ai/halogen-qwen3.8-flash-next" = {
        proxy = "http://127.0.0.1:8731";
        checkEndpoint = "/health";
        useModelName = "halogen-qwen3.8-flash-next";
        cmd = ''
          ${podman} run --rm --replace --name ${halogenContainer}
          -p 8731:8731
          --device /dev/kfd --device /dev/dri --group-add keep-groups
          --security-opt seccomp=unconfined --ipc=host --ulimit memlock=-1:-1
          -v /home/mani/halogen-models:/models:ro
          ghcr.io/peonist-ai/halogen-flash-server:0.5.6
        '';
        cmdStop = "${podman} stop --ignore --time 30 ${halogenContainer}";
        unloadTimeout = 45;
        capabilities = {
          "in" = [ "text" ];
          out = [ "text" ];
          tools = true;
          context = 262144;
        };
      };
    };

    routing.router = {
      use = "group";
      settings.groups."large-gguf" = {
        swap = true;
        exclusive = true;
        members = [
          "Qwen3.6-35B-A3B-MTP-GGUF"
          "Qwen3.8-27B-GGUF"
          "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF"
          "Gemma-4-26B-A4B-it-MTP-GGUF"
          "peonist-ai/halogen-qwen3.8-flash-next"
        ];
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
      # LiteLLM exposes the maintenance and TTS routes through its unified API.
      # Keep Lemonade reachable directly for diagnostics and recovery.
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
      StateDirectory = "llama-swap";
    };
    environment = {
      HSA_ENABLE_SDMA = "0";
      HIP_VISIBLE_DEVICES = "0";
      # Rootless Podman invokes the setuid newuidmap/newgidmap helpers by
      # name.  systemd's restricted default PATH omits the NixOS wrappers.
      PATH = lib.mkForce "/run/wrappers/bin:/run/current-system/sw/bin";
    };
  };

  networking.firewall.allowedTCPPorts = [ 9292 13305 ];

  environment.systemPackages = with pkgs; [
    amdgpu_top
    vulkan-tools
    lmstudio
    llama-swap
  ];
}
