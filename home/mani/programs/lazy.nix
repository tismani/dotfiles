{ pkgs, ... }:

{
  programs.lazydocker = {
    enable = true;
    # Dracula, hand-matched like herdr; stylix has no lazydocker target.
    settings.gui.theme = {
      activeBorderColor = [ "#bd93f9" "bold" ];
      inactiveBorderColor = [ "#6272a4" ];
      selectedLineBgColor = [ "#44475a" ];
    };
  };

  # Themed by stylix's lazygit target.
  programs.lazygit.enable = true;
}
