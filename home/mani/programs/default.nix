{ pkgs, ... }: {

  imports = [
    ./kitty.nix
    ./yt-dlp.nix
    ./starship.nix
  ];
}
