{ pkgs, ... }:

{
  programs.superfile = {
    enable = true;

    # Settings captured from the on-disk config.toml. With
    # ignore_missing_fields = true, superfile fills in defaults for any key
    # not listed here, so only the user's explicit overrides are needed.
    settings = {
      auto_check_update = false;
      cd_on_quit = true;
      editor = "hx";
      ignore_missing_fields = true;
      theme = "dracula";
    };

    # Default superfile keymap (matches src/superfile_config/hotkeys.toml).
    hotkeys = {
      # Global hotkeys — basic actions
      confirm = [ "enter" "right" "l" ];
      cd_quit = [ "ctrl+q" ];
      quit = [ "q" ];
      # navigation
      list_down = [ "down" "j" ];
      list_up = [ "up" "k" ];
      page_down = [ "pgdown" ];
      page_up = [ "pgup" ];
      # file panel controls
      close_file_panel = [ "w" ];
      create_new_file_panel = [ "n" ];
      next_file_panel = [ "tab" "L" ];
      open_sort_options_menu = [ "o" ];
      pinned_directory = [ "P" ];
      previous_file_panel = [ "shift+left" "H" ];
      split_file_panel = [ "N" ];
      toggle_file_preview_panel = [ "f" ];
      toggle_reverse_sort = [ "R" ];
      # focus manipulation
      focus_on_metadata = [ "m" ];
      focus_on_process_bar = [ "p" ];
      focus_on_sidebar = [ "s" ];
      # file/dir creation/renaming
      file_panel_item_create = [ "ctrl+n" ];
      file_panel_item_rename = [ "ctrl+r" ];
      # main file operations
      copy_items = [ "ctrl+c" ];
      cut_items = [ "ctrl+x" ];
      delete_items = [ "ctrl+d" "delete" ];
      paste_items = [ "ctrl+v" "ctrl+w" ];
      permanently_delete_items = [ "D" ];
      # archive manipulation
      compress_file = [ "ctrl+a" ];
      extract_file = [ "ctrl+e" ];
      # editor actions
      open_current_directory_with_editor = [ "E" ];
      open_file_with_editor = [ "e" ];
      # other actions
      change_panel_mode = [ "v" ];
      copy_path = [ "ctrl+p" ];
      copy_present_working_directory = [ "c" ];
      open_command_line = [ ":" ];
      open_help_menu = [ "?" ];
      open_spf_prompt = [ ">" ];
      open_zoxide = [ "z" ];
      toggle_dot_file = [ "." ];
      toggle_footer = [ "F" ];
      # typing hotkeys
      confirm_typing = [ "enter" ];
      cancel_typing = [ "ctrl+c" "esc" ];
      # normal mode
      parent_directory = [ "h" "left" "backspace" ];
      search_bar = [ "/" ];
      # selection mode
      file_panel_select_mode_items_select_down = [ "shift+down" "J" ];
      file_panel_select_mode_items_select_up = [ "shift+up" "K" ];
      file_panel_select_all_items = [ "A" ];
    };
  };
}
