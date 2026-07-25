# Per-user niri + noctalia desktop (Linux only — imported conditionally from
# home/mani/default.nix). GTK/cursor/icon theming comes from stylix, so there
# is no separate theming module here.
{ ... }:

{
  imports = [
    ./niri.nix
    ./noctalia.nix
  ];

  # stylix's qt target defaults to the "gnome" platform, which upstream now
  # rejects (only "qtct" is supported) and which also sets the deprecated
  # qt.platformTheme.name = "gnome". Pin qtct to silence both warnings.
  stylix.targets.qt.platform = "qtct";

  # stylix populates home.pointerCursor.* but relies on the deprecated
  # auto-enable. Set it explicitly.
  home.pointerCursor.enable = true;
}
