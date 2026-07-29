# halo never suspends or hibernates: it is a desktop that has to stay reachable
# over ssh/tailscale and keep the lemonade LLM service running.
#
# The *display* still sleeps — GNOME's idle blank/lock is left at its defaults,
# only the machine-level power transitions are taken away.
#
# Three layers have to be disabled independently; each one can suspend the box
# on its own:
#   1. GDM, before anyone logs in.
#   2. GNOME's own idle timer, once logged in (dconf, not a NixOS option).
#   3. systemd/logind, the mechanism underneath both.
{ ... }:

{
  # 1. Login screen. Explicitly does NOT cover the logged-in session — see the
  # option's description in nixos/modules/services/display-managers/gdm.nix.
  services.displayManager.gdm.autoSuspend = false;

  # 2. Logged-in GNOME session. gnome-settings-daemon reads these from dconf;
  # there is no NixOS option for them. `lockAll` is needed because a value
  # already written to the per-user database (by the Settings UI) otherwise wins
  # over a mere default — the cost is that the matching toggles in GNOME
  # Settings are greyed out.
  #
  # `org/gnome/desktop/session idle-delay` is deliberately left alone so the
  # screen still blanks and locks on idle.
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "nothing";
      };
      lockAll = true;
    }
  ];

  # 3. Mask the sleep units outright, so nothing — a stray `systemctl suspend`,
  # another desktop, a service — can put the machine down. logind then reports
  # CanSuspend=no and GNOME drops Suspend from the power menu altogether.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
    suspend-then-hibernate.enable = false;
  };

  # Belt and braces: no idle timer and no keyboard sleep key triggers a
  # transition either.
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
  };
}
