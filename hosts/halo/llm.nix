{ pkgs, lib, ... }:

let
  llamaSwapConfig = (pkgs.formats.yaml { }).generate "llama-swap.yaml" {
    healthCheckTimeout = 600;
    logLevel = "info";
    logToStdout = "both";
    sendLoadingState = true;

    # Download with Lemonade, then register absolute GGUF paths here.
    # See docs/halo-llm.md. Default swapping behavior applies.
    models = {
      # "my-model" = {
      #   cmd = ''
      #     ${pkgs.llama-cpp-rocm}/bin/llama-server
      #     --host 127.0.0.1 --port ''${PORT}
      #     --n-gpu-layers 999 --flash-attn on --no-mmap --jinja
      #     --ctx-size 131072 --parallel 1
      #     --threads 16 --batch-size 2048 --ubatch-size 512
      #     --model /absolute/path/model.gguf --alias my-model
      #   '';
      #   # Optionally append to cmd for compatible models:
      #   # --mmproj /absolute/path/mmproj.gguf
      #   # --model-draft /absolute/path/draft.gguf
      # };
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
      host = "127.0.0.1";
      settings = {
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

  systemd.services.llama-swap = {
    description = "On-demand llama.cpp gateway";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "mani";
      Group = "users";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${lib.getExe pkgs.llama-swap} --config ${llamaSwapConfig} --listen 0.0.0.0:9292";
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

  networking.firewall.allowedTCPPorts = [ 9292 ];

  environment.systemPackages = with pkgs; [
    amdgpu_top
    vulkan-tools
    lmstudio
    llama-swap
  ];
}
