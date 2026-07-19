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

    lemonade = {
      user = "mani";
      host = "0.0.0.0"; # reachable on the LAN (default: localhost)
      # port defaults to 13305
    };

    # Strix Halo / 128 GB unified-memory tuning. Emitted as the ttm
    # pages_limit + page_pool_size modprobe options.
    gpuMemory = {
      ttmSizeGiB = 112;
      pagePoolSizeGiB = 112;
    };
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
