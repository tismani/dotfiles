{ pkgs, ... }: {

  imports = [
    ./kitty.nix
    ./yt-dlp.nix
    ./starship.nix
    ./tmux.nix
    ./ssh.nix
    ./helix.nix
  ];
}
