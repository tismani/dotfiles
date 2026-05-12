{ pkgs, ... }: {

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    warn-dirty = false;
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 14d";
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    ripgrep
    fd
    bat
    eza
    htop
    jq
    unzip
    tree
    uv
    kitty
    yt-dlp

    nodejs_24
    postman
    kubectl
    minikube

    # requires nixpkgs.config.allowUnfree = true;
    vscode
    vscode-extensions.ms-vscode-remote.remote-ssh
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];
}
