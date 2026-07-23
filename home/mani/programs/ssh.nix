{ pkgs, ... }: {

  # Public half of the keypairs; the private key lives only in Bitwarden.
  home.file.".ssh/halo.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrXTBSu8Qc25QC+4Y5Lk0mwzOlF9xTZBCKqjhpFYSRI\n";
  home.file.".ssh/bouncer.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnGLS7pEDW1aAFeT2CLfH3yx2OVGFPfZdxpx86KJpIU\n";
  home.file.".ssh/hostinger.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJB31gq6Jv0QwEOs23AGjAif3i7wkTtrXi/jf2BXxoW\n";
  home.file.".ssh/pve.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4u1ArDc1SCrmA3qLBVmTQY353v69n2D/XuOLRB76e8\n";
  home.file.".ssh/services.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5AgLM722FbpRbHzI9GpD/6Vpzw8V80Ga+d8LAp+TWr\n";

  programs.ssh = {
    enable = true;

    # Home-manager's implicit `Host *` defaults are being removed upstream;
    # opt out and set the ones we want ourselves to silence the warning.
    enableDefaultConfig = false;

    settings = {
      "*" = {
        # Bitwarden desktop app's SSH agent socket.
        # nightfury: Bitwarden installed via Mac App Store (sandboxed container path).
        # halo: Bitwarden installed via Flatpak.
        IdentityAgent =
          if pkgs.stdenv.isDarwin
          then "~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
          else "~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";

        # Former home-manager defaults, kept verbatim.
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      # These three keys live only on disk, not in Bitwarden. With a global
      # IdentityAgent configured, OpenSSH routes explicitly-configured
      # IdentityFile offers through the agent first ("explicit agent" in
      # `ssh -v`); since Bitwarden doesn't hold these keys, that silently
      # fails auth instead of falling back to reading the file directly.
      # IdentityAgent none keeps them on the old, working, agent-free path.
      # Forgejo is setup like this, so octarine can use Forgejo
      "10.1.2.155" = {
        HostName = "10.1.2.155";
        User = "git";
        IdentityFile = "~/.ssh/forgejo.key";
        IdentitiesOnly = true;
        IdentityAgent = "none";
      };

      "10.1.2.119" = {
        HostName = "10.1.2.119";
        User = "ubuntu";
        IdentityFile = "~/.ssh/hermes.key";
        IdentitiesOnly = true;
        IdentityAgent = "none";
      };

      # halo's key lives only in Bitwarden, so it's the one host that should
      # actually go through the agent (set globally on Host * above).
      halo = {
        HostName = "10.1.3.246";
        User = "mani";
        IdentityFile = "~/.ssh/halo.pub";
        IdentitiesOnly = true;
      };

      hostinger = {
        HostName = "195.35.22.19";
        User = "mani";
        IdentityFile = "~/.ssh/hostinger.pub";
        IdentitiesOnly = true;
      };

      pve = {
        HostName = "10.1.2.99";
        User = "root";
        IdentityFile = "~/.ssh/pve.pub";
        IdentitiesOnly = true;
      };

      bouncer = {
        HostName = "10.1.2.10";
        User = "mani";
        IdentityFile = "~/.ssh/bouncer.pub";
        IdentitiesOnly = true;
      };

      services = {
        HostName = "10.1.2.102";
        User = "mani";
        IdentityFile = "~/.ssh/services.pub";
        IdentitiesOnly = true;
      };
    };
  };
}
