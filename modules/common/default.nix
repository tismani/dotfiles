{ pkgs, ... }: {

  imports = [ ./stylix.nix ];

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
  };

  # scheduled optimisation instead of auto-optimise-store,
  # which has a history of store corruption on macOS
  nix.optimise.automatic = true;

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
    ffmpeg
    zoxide
    anki-bin # pkgs.anki compiles qtspeech from source, broken on aarch64-darwin

    nodejs_24
    rustc
    rust-analyzer
    cargo
    cargo-tauri
    pkg-config
    claude-code
    postman
    kubectl
    minikube
    fira-code-symbols

    # requires nixpkgs.config.allowUnfree = true;
    (vscode-with-extensions.override {
      vscodeExtensions = with vscode-extensions; [
        ms-vscode-remote.remote-ssh
      ];
    })
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];
}
