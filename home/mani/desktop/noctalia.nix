# noctalia-shell: a complete Quickshell-based desktop shell (bar, launcher,
# notifications, lock screen, wallpaper manager, control center, dock, OSDs and
# clipboard history). It is launched from niri's spawn-at-startup (see
# niri.nix) and configured live through its own settings GUI.
#
# The nixpkgs package already wraps its runtime deps (brightnessctl, ddcutil,
# cliphist, wl-clipboard, wlsunset, imagemagick, bluez, ...) into PATH by
# default; here we additionally turn on screen recording and the calendar.
{ pkgs, ... }:

{
  home.packages = [
    (pkgs.noctalia-shell.override {
      gpuScreenRecorderSupport = true;
      calendarSupport = true;
    })
  ];
}
