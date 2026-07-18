{ config, pkgs, ... }:

{
  # Ensure you have a recent kernel for hardware stability
  boot.kernelPackages = pkgs.linuxPackages_latest; 
  # Set your TTM limits to allow for maximum VRAM allocation.
  # Calculation for bytes: (Size in GB * 1024 * 1024) / 4.096
  # For 112GB: 112 * 1024 * 1024 / 4.096 = 28672000
  boot.kernelParams = [
    "amdgpu.gttsize=117760"            # Sets GTT pool to approx 115GB
    "amdttm.pages_limit=28672000"      # TTM Pages limit for max allocation
    "amdttm.page_pool_size=28672000"   # TTM pool size
  ];

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
    environmentVariables = {
      OLLAMA_LLM_LIBRARY = "vulkan";
      OLLAMA_VULKAN = "1";
    };

    package = pkgs.ollama-vulkan;
  };

  # Lemonade Server (AMD's local LLM server, ROCm/NPU-accelerated) via
  # container, since it isn't packaged in nixpkgs.
  # https://lemonade-server.ai/docs/guide/install/docker/
  virtualisation.podman.enable = true;

  # Pre-seed the ROCm backend config that lemonade-server reads on startup.
  system.activationScripts.lemonadeConfig = ''
    mkdir -p /var/lib/lemonade/{cache,llama,recipe}
    cat > /var/lib/lemonade/recipe/config.json <<'EOF'
    {
      "llamacpp": {
        "backend": "rocm"
      }
    }
    EOF
  '';

  virtualisation.oci-containers = {
    backend = "podman";
    containers.lemonade-server = {
      image = "ghcr.io/lemonade-sdk/lemonade-server:latest";
      autoStart = true;
      ports = [ "13305:13305" ];
      volumes = [
        "/var/lib/lemonade/cache:/opt/lemonade/.cache/huggingface"
        "/var/lib/lemonade/llama:/opt/lemonade/llama"
        "/var/lib/lemonade/recipe:/opt/lemonade/.cache/lemonade"
      ];
      extraOptions = [
        "--device=/dev/kfd"
        "--device=/dev/dri"
      ];
    };
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    environment = {
      OPENAI_API_BASE_URL = "http://127.0.0.1:13305/api/v1";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
    };
  };

  # Open ports to make it accessible to the network
  networking.firewall.allowedTCPPorts = [ 11434 1234 13305 ];

  # Required system packages to load the Vulkan runtime
  environment.systemPackages = with pkgs; [
    vulkan-loader
    vulkan-tools
    amdgpu_top
    lmstudio
  ];
}
