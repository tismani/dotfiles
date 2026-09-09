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
      rebuild-halo = "nixos-rebuild switch --flake ~/dotfiles#halo --target-host mani@halo --build-host mani@halo --elevate=sudo --ask-elevate-password";
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

      function fish_user_key_bindings
        if command -s fzf-share >/dev/null
          source (fzf-share)/key-bindings.fish
        end

        fzf_key_bindings
      end
    '';
  };
}
