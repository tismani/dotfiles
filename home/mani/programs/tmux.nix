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
        plugin = dracula;
        extraConfig = ''
          # Status bar modules (right side)
          set -g @dracula-plugins "git cpu-usage ram-usage time"
          set -g @dracula-show-powerline true
          set -g @dracula-show-left-icon session
          set -g @dracula-show-flags true
          set -g @dracula-refresh-rate 5

          # Date/time
          set -g @dracula-military-time true
          set -g @dracula-time-format "%a %d %b  %H:%M"
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
    '';
  };

  # The Dracula tmux plugin owns the status bar; keep stylix from also theming
  # tmux so the two don't fight over the status line.
  stylix.targets.tmux.enable = false;
}