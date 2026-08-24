{ ... }:

{
  programs.herdr = {
    enable = true;

    settings = {
      # Stylix has no herdr target, so the theme is set by hand. "dracula" is a
      # herdr built-in and matches modules/common/stylix.nix.
      theme = {
        name = "dracula";
        # Let the outer terminal's background show through the sidebar and
        # panels instead of painting them opaque, so stylix's
        # opacity.terminal = 0.9 still applies inside herdr.
        custom.panel_bg = "reset";
      };

      # Equivalent of tmux's split-window -c "#{pane_current_path}": new panes,
      # tabs and workspaces inherit the current directory.
      terminal.new_cwd = "follow";

      # nixpkgs owns the version, so silence the built-in updater rather than
      # be nagged about releases `herdr update` cannot install into the store.
      update.version_check = false;

      # Replaces the resurrect + continuum plugin pair. herdr runs a background
      # server, so panes survive detach and reboot on their own.
      session.resume_agents_on_restore = true;

      keys = {
        prefix = "ctrl+a";
        detach = "prefix+d";

        # Splits keep the tmux mnemonics: | is side-by-side, - is stacked.
        split_vertical = "prefix+|";
        split_horizontal = "prefix+-";

        # prefix+m is the old tmux binding; prefix+z is herdr's default.
        zoom = [ "prefix+m" "prefix+z" ];

        copy_mode = "prefix+[";
        last_pane = "prefix+a";
      };

      ui = {
        mouse_capture = true;
        copy_on_select = true;

        # tmux created windows instantly; skip herdr's name prompt to match.
        prompt_new_tab_name = false;
        hide_tab_bar_when_single_tab = true;

        # Route agent state changes to macOS/Linux notifications rather than
        # in-app toasts, since the point is noticing a blocked agent while
        # herdr is in the background.
        toast.delivery = "system";
      };
    };
  };
}
