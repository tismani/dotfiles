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
      if pkgs.stdenv.isDarwin
      then "sudo darwin-rebuild switch --flake ~/dotfiles"
      else "sudo nixos-rebuild switch --flake ~/dotfiles";
    } // lib.optionalAttrs pkgs.stdenv.isDarwin {
      rebuild-halo = "nixos-rebuild switch --flake ~/dotfiles#halo --target-host mani@halo --build-host mani@halo --use-remote-sudo --ask-elevate-password";
    };
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      starship init fish | source
      zoxide init fish | source
      direnv hook fish | source

      function fish_user_key_bindings
        if command -s fzf-share >/dev/null
          source (fzf-share)/key-bindings.fish
        end

        fzf_key_bindings
      end
    '';
  };
}
