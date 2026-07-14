{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    prefix = "C-a";
    mouse = true;
    keyMode = "vi";
    escapeTime = 10;

    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      {
        plugin = catppuccin;
        extraConfig = ''
          # Theme flavor: latte, frappe, macchiato, mocha
          set -g @catppuccin_flavor 'mocha'

          # Window styling
          set -g @catppuccin_window_status_style 'rounded'
          set -g @catppuccin_window_number_position 'right'
          set -g @catppuccin_window_default_fill 'number'
          set -g @catppuccin_window_default_text '#W'
          set -g @catppuccin_window_current_fill 'number'
          set -g @catppuccin_window_current_text '#W'

          # Status bar modules
          set -g @catppuccin_status_modules_right 'directory session date_time'
          set -g @catppuccin_status_modules_left ""
          set -g @catppuccin_status_left_separator '█'
          set -g @catppuccin_status_right_separator '█'

          # Directory
          set -g @catppuccin_directory_text '#{pane_current_path}'

          # Date/time
          set -g @catppuccin_date_time_text '%a %d %b  %H:%M'

          # Pane borders
          set -g @catppuccin_pane_border_style 'fg=#{thm_surface0}'
          set -g @catppuccin_pane_active_border_style 'fg=#{thm_lavender}'
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
    ];

    extraConfig = ''
      # Undercurl support
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      # Unbind defaults
      unbind C-b
      unbind %
      unbind '"'

      # Split panes in current path
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Resize panes
      bind j resize-pane -D 5
      bind k resize-pane -U 5
      bind l resize-pane -R 5
      bind h resize-pane -L 5
      bind -r m resize-pane -Z

      # Set session path to current pane
      bind M-c attach-session -c "#{pane_current_path}"

      # Vi copy mode tweaks
      bind-key -T copy-mode-vi 'v' send -X begin-selection
      bind-key -T copy-mode-vi 'y' send -X copy-selection
      unbind -T copy-mode-vi MouseDragEnd1Pane

      # Transparent status bar background for a clean look
      set -g status-bg default
      set -g status-style bg=default
    '';
  };
}