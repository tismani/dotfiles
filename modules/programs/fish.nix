{ pkgs, ... }: {

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
      rebuild = "sudo darwin-rebuild switch --flake ~/dotfiles#nightfury";
      cd = "z";
    };
    interactiveShellInit = ''
          set fish_greeting # Disable greeting
          starship init fish | source
          zoxide init fish | source

          function fish_user_key_bindings
            if command -s fzf-share >/dev/null
              source (fzf-share)/key-bindings.fish
            end

            fzf_key_bindings
          end
        '';
  };
}
