# Per-user niri + noctalia desktop (Linux only — imported conditionally from
# home/mani/default.nix). GTK/cursor/icon theming comes from stylix, so there
# is no separate theming module here.
{ ... }:

{
  imports = [
    ./niri.nix
    ./noctalia.nix
  ];

  # stylix populates home.pointerCursor.* but relies on the deprecated
  # auto-enable. Set it explicitly.
  home.pointerCursor.enable = true;
}
