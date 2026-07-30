{ pkgs, inputs, ... }: {

  imports = [ ./stylix.nix ];

  nixpkgs.config.allowUnfree = true;

  # `pkgs.stable.<name>` pulls a single package from the stable channel while
  # everything else stays on unstable. Deliberately additive: overriding
  # `pkgs.<name>` directly would swap the package for every consumer of it and
  # trigger mass rebuilds. Costs a second nixpkgs evaluation, so use sparingly,
  # and prefer it only for standalone applications — mixing stable *libraries*
  # into unstable builds is a good way to get subtle breakage.
  nixpkgs.overlays = [
    (final: prev: {
      stable = import inputs.nixpkgs-stable {
        inherit (final.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    })
  ];

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
