# Declarative niri configuration. Keybinds drive kitty (terminal) and noctalia
# (launcher / lock / notifications / bar / wallpaper) over noctalia's IPC.
# Colours are pulled from the active stylix (Dracula) base16 palette so niri
# matches the rest of the system.
{ config, pkgs, ... }:

let
  c = config.lib.stylix.colors.withHashtag;
in
{
  xdg.configFile."niri/config.kdl".text = ''
    // Managed by home-manager (home/mani/desktop/niri.nix).
    // Colours come from the stylix Dracula base16 palette.

    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
            natural-scroll
        }
        mouse {
            natural-scroll
        }
        warp-mouse-to-focus
    }

    // Monitor modes are auto-detected. Add `output "<name>" { ... }` blocks
    // here to pin resolution / scale / position for specific displays.

    cursor {
        xcursor-theme "Bibata-Modern-Ice"
        xcursor-size 24
    }

    layout {
        gaps 12
        // Keep the focused/active column centered on screen at all times.
        center-focused-column "always"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        // New windows open at 70% of the output width.
        default-column-width { proportion 0.7; }

        focus-ring {
            width 3
            active-gradient from="${c.base0D}" to="${c.base0E}" angle=45
            inactive-color "${c.base03}"
        }

        border {
            off
        }

        shadow {
            on
            softness 30
            spread 5
            offset x=0 y=5
            color "#00000070"
        }

        struts {
            left 0
            right 0
            top 0
            bottom 0
        }
    }

    // Ask apps to omit client-side decorations so niri can draw clean rounded
    // corners and its own focus ring.
    prefer-no-csd

    window-rule {
        geometry-corner-radius 10
        clip-to-geometry true
    }

    // Firefox: open at 80% width, never maximized or fullscreen.
    window-rule {
        match app-id=r#"firefox$"#
        default-column-width { proportion 0.8; }
        open-maximized false
        open-fullscreen false
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    hotkey-overlay {
        skip-at-startup
    }

    environment {
        DISPLAY ":0"
        NIXOS_OZONE_WL "1"
    }

    // Shell + X11 bridge. noctalia provides the bar, launcher, notifications,
    // lock screen, wallpaper and clipboard history.
    spawn-at-startup "noctalia-shell"
    spawn-at-startup "xwayland-satellite"

    // Idle / Power Management
    spawn-at-startup "swayidle" "-w" "timeout" "600" "noctalia-shell" "ipc" "call" "lockScreen" lock"
    spawn-at-startup "swayidle" "-w" "timeout" "660" "niri msg action power-off-monitors"

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Programs
        Mod+Return hotkey-overlay-title="Terminal: kitty" { spawn "kitty"; }
        Mod+T hotkey-overlay-title="Terminal: kitty" { spawn "kitty"; }
        Mod+D hotkey-overlay-title="App Launcher" { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Mod+Space hotkey-overlay-title="App Launcher" { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Super+Alt+L hotkey-overlay-title="Lock Screen" { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
        Mod+N hotkey-overlay-title="Notification History" { spawn "noctalia-shell" "ipc" "call" "notifications" "toggleHistory"; }
        Mod+B hotkey-overlay-title="Toggle Bar" { spawn "noctalia-shell" "ipc" "call" "bar" "toggle"; }
        Mod+Shift+W hotkey-overlay-title="Wallpaper Picker" { spawn "noctalia-shell" "ipc" "call" "wallpaper" "toggle"; }

        // Audio / media keys
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-"; }
        XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
        XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }
        XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }

        // External-monitor brightness over DDC/CI (VCP feature 0x10).
        XF86MonBrightnessUp   allow-when-locked=true { spawn-sh "ddcutil setvcp 10 + 10"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn-sh "ddcutil setvcp 10 - 10"; }

        // Overview + window management
        Mod+O repeat=false { toggle-overview; }
        Mod+Q { close-window; }

        Mod+Left  { focus-column-left; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+J     { focus-window-down; }
        Mod+K     { focus-window-up; }
        Mod+L     { focus-column-right; }

        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Down  { move-window-down; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H     { move-column-left; }
        Mod+Ctrl+J     { move-window-down; }
        Mod+Ctrl+K     { move-window-up; }
        Mod+Ctrl+L     { move-column-right; }

        Mod+Home { focus-column-first; }
        Mod+End  { focus-column-last; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }

        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up   { focus-workspace-up; }
        Mod+U         { focus-workspace-down; }
        Mod+I         { focus-workspace-up; }

        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }

        Mod+Comma  { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+C { center-column; }

        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }

        Mod+V { toggle-window-floating; }

        // Screenshots (niri built-in; no external tools needed)
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // Session
        Mod+Shift+E { quit; }
        Mod+Shift+P { power-off-monitors; }
    }
  '';

  # polkit authentication agent for the niri session (privilege dialogs).
  # GNOME's own session starts this itself; niri does not, so run it here.
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "polkit-gnome authentication agent";
      WantedBy = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };
}
