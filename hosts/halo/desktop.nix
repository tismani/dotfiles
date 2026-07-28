# Second desktop environment for halo: niri (a scrollable-tiling Wayland
# compositor) alongside the existing GNOME session.
#
# System-level pieces only. The per-user compositor + shell configuration
# (niri KDL, noctalia) lives in home/mani/desktop/. Theming is handled by
# stylix (modules/common/stylix.nix); the cursor is set here because it is a
# Linux-only stylix option.
#
# Toggle with `desktop.niri.enable = false;` (e.g. in configuration.nix) to
# drop niri and go GNOME-only, without deleting this module.
{ pkgs, lib, config, ... }:

let
  cfg = config.desktop.niri;
in
{
  options.desktop.niri.enable = lib.mkEnableOption "the niri desktop environment (alongside GNOME)" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    # Registers a "Niri" session in GDM and wires up the pieces niri needs:
    # xdg portals (gnome + gtk), gnome-keyring, dconf and the polkit *service*.
    # See nixos/modules/programs/wayland/niri.nix. Note: this does NOT start a
    # polkit authentication *agent* and leaves XWayland off — both handled below
    # (agent as a user service in home/mani/desktop/niri.nix).
    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      # niri is Wayland-only; this bridges X11-only apps into the session.
      xwayland-satellite
      # polkit authentication agent (privilege-escalation dialogs), started from
      # the niri session as a user service.
      polkit_gnome
      # halo is a *desktop*: brightness is controlled over DDC/CI on the external
      # monitor, not a backlight. noctalia drives this; the CLI is handy too.
      ddcutil
      wl-clipboard
      libnotify
      playerctl
      swayidle
    ];

    # DDC/CI monitor brightness. Creates the "i2c" group and loads i2c-dev so
    # ddcutil (and noctalia's brightness OSD) can talk to the monitor.
    hardware.i2c.enable = true;
    users.users.mani.extraGroups = [ "i2c" ]; # merges with the list in configuration.nix

    # Bluetooth — noctalia provides the control-center UI for it.
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;

    # Cursor theme (Linux-only stylix option). Applies to GTK apps and, via the
    # niri config, the compositor cursor.
    stylix.cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    # Pull in the per-user niri + noctalia config for mani, but only on this
    # (Linux) host — keeping it out of the shared home config avoids evaluating
    # Linux-only options (systemd.user services) on darwin.
    home-manager.users.mani.imports = [ ../../home/mani/desktop ];
  };
}
