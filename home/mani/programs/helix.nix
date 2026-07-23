{ pkgs, ... }:

{
  programs.helix = {
    enable = true;

    settings = {
      theme = "catppuccin_mocha";

      editor = {
        line-number = "relative";
        mouse = true;
        bufferline = "multiple";
        color-modes = true;
        true-color = true;

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        whitespace.render = "all";
        indent-guides.render = true;
        soft-wrap.enable = true;

        file-picker.hidden = false;

        lsp = {
          display-inlay-hints = true;
          display-messages = true;
        };
      };

      keys.insert = {
        "j" = { "k" = "normal_mode"; };
      };
    };
  };
}
