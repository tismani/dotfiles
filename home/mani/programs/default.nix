{ pkgs, ... }: {

  imports = [
    ./kitty.nix
    ./yt-dlp.nix
    ./starship.nix
    ./herdr.nix
    ./ssh.nix
    ./helix.nix
    ./omp.nix
    ./superfile.nix
  ];
}
