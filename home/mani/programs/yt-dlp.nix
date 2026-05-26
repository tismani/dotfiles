{ pkgs, ... }:

{
  programs = {
    yt-dlp = {
      enable = true;
      settings = {
        audio-format = "best";
        audio-quality = 0;
        embed-chapters = true;
        embed-metadata = true;
        embed-subs = true;
        embed-thumbnail = true;
        sponsorblock-mark = "sponsor";
        sub-langs = "all";
      };
      extraConfig = ''
        --ffmpeg-location /run/current-system/sw/bin/ffmpeg
      '';
    };
  };
}
