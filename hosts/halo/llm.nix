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

  # Open ports to make it accessible to the network
  networking.firewall.allowedTCPPorts = [ 11434 1234 ];

  # Required system packages to load the Vulkan runtime
  environment.systemPackages = with pkgs; [
    vulkan-loader
    vulkan-tools
    amdgpu_top
    lmstudio
  ];
}
