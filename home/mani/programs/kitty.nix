{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    # Font (FiraCode Nerd Font Mono @ 13) and background opacity are set by
    # stylix — see modules/common/stylix.nix (fonts.sizes.terminal /
    # opacity.terminal). Colours come from the stylix Dracula theme.

    keybindings = {
      "ctrl+c" = "copy_or_interrupt";
      "ctrl+equal" = "change_font_size all +1.0";
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+0" = "change_font_size all 0";
    };

    settings = {
      cursor_shape = "beam";
      cursor_trail = 1;
      cursor_trail_color = "#bd93f9"; # Dracula purple

      window_margin_width = "21";

      background_blur = 1;

      copy_on_select = "yes";
      strip_trailing_spaces = "smart";
      confirm_os_window_close = 0;

      # shell = "zsh";
      shell = "/run/current-system/sw/bin/fish";
      shell_integration = "enabled";
    };

    # Colours come from stylix (Dracula). Font/opacity above are explicit and
    # take precedence over stylix's defaults.

    # Right-click pastes from clipboard (mouse_map isn't exposed as a HM
    # option, so it goes in raw config).
    extraConfig = ''
      mouse_map right press ungrabbed paste_from_clipboard
    '';
  };
}
