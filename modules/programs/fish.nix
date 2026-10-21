{ pkgs, lib, ... }: {

  environment.systemPackages = with pkgs; [
    fishPlugins.done
    fishPlugins.forgit
    fishPlugins.hydro
    fzf
    fishPlugins.grc
    grc
  ];

  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "eza -l -g --icons";
      cat = "bat";
      cd = "z";
      rebuild =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "sudo darwin-rebuild switch --flake ~/dotfiles"
      else "sudo nixos-rebuild switch --flake ~/dotfiles";
    } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      # Build on halo (not the macOS host): rsync the working tree, then switch.
      # Builds what's in ~/dotfiles here, including uncommitted changes.
      # rsync skips .git, so the remote clone's index doesn't know new files and
      # flakes ignore untracked files; `git add -A` there makes them visible.
      rebuild-halo =
      "rsync -az --delete --exclude .git --exclude result ~/dotfiles/ mani@halo:~/dotfiles/ && ssh mani@halo 'cd ~/dotfiles && git add -A && sudo nixos-rebuild switch --flake ~/dotfiles#halo'";
      # Same as rebuild-halo, for ajwa, over Tailscale (MagicDNS name ts-ajwa).
      rebuild-ajwa =
      "rsync -az --delete --exclude .git --exclude result ~/dotfiles/ mani@ts-ajwa:~/dotfiles/ && ssh -t mani@ts-ajwa 'cd ~/dotfiles && git add -A && sudo nixos-rebuild switch --flake ~/dotfiles#ajwa'";
    };
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      starship init fish | source
      zoxide init fish | source
      direnv hook fish | source

      # The SSH kitten installs Kitty's terminfo on the remote host.
      # Keep ordinary SSH in other terminals and if kitten is unavailable.
      function ssh --wraps ssh --description 'SSH with Kitty terminal support'
        if set -q KITTY_WINDOW_ID; and command -q kitten
          command kitten ssh $argv
        else
          command ssh $argv
        end
      end

      # cd_on_quit: source the lastdir file after superfile exits so the
      # shell changes to the last directory open in superfile.
      function superfile
        set os (uname -s)
        if test "$os" = "Linux"
          set spf_last_dir "$HOME/.local/state/superfile/lastdir"
        else if test "$os" = "Darwin"
          set spf_last_dir "$HOME/Library/Application Support/superfile/lastdir"
        end
        command superfile $argv
        if test -f "$spf_last_dir"
          source "$spf_last_dir"
          rm -f -- "$spf_last_dir" >> /dev/null
        end
      end

      function fish_user_key_bindings
        if command -s fzf-share >/dev/null
          source (fzf-share)/key-bindings.fish
        end

        fzf_key_bindings
      end
    '';
  };
}
