# System-wide Dracula theme via stylix. Shared by every host (NixOS + darwin).
#
# Only cross-platform settings live here. Anything Linux-only (cursor theme,
# desktop targets) is set in the host that needs it. Because home-manager is a
# system module, stylix propagates these into our home config automatically, so
# kitty, helix, bat, fish, starship, GTK, etc. all get themed from here.
# (herdr has no stylix target; its theme is set in home/mani/programs/herdr.nix.)
{ pkgs, ... }:

{
  stylix = {
    enable = true;

    # Dracula base16 palette from the tinted-theming collection. Setting this
    # explicitly means stylix does not need a wallpaper to derive colors.
    base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };

      # Preserve the terminal font size we used before stylix.
      sizes.terminal = 13;
    };

    # Semi-transparent terminal background (kitty had background_opacity 0.9).
    opacity.terminal = 0.9;
  };
}
