{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "FiraCode Nerd Font Mono";
      size = 13.0;
    };

    keybindings = {
      "ctrl+c" = "copy_or_interrupt";
      "ctrl+equal" = "change_font_size all +1.0";
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+0" = "change_font_size all 0";
    };

    settings = {
      cursor_shape = "beam";
      cursor_trail = 1;
      cursor_trail_color = "#b4befe";

      window_margin_width = "21";

      background_opacity = "0.9";
      background_blur = 1;

      copy_on_select = "yes";
      strip_trailing_spaces = "smart";
      confirm_os_window_close = 0;

      # shell = "zsh";
      shell = "/run/current-system/sw/bin/fish";
      shell_integration = "enabled";
    };

    # Catppuccin Mocha theme
    themeFile = "Catppuccin-Mocha";
  };
}
