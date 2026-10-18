{ pkgs, ... }:

let
  # Bitwarden desktop app's SSH agent socket. Both installs are sandboxed, so
  # neither uses the plain ~/.bitwarden-ssh-agent.sock that a native install gets.
  # nightfury: Bitwarden installed via Mac App Store (sandboxed container path).
  # halo: Bitwarden installed via Flatpak (see hosts/halo/flatpak.nix).
  bitwardenAgent =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
    else "~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";
in {

  # Public half of the keypairs; the private key lives only in Bitwarden.
  home.file.".ssh/halo.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrXTBSu8Qc25QC+4Y5Lk0mwzOlF9xTZBCKqjhpFYSRI\n";
  home.file.".ssh/bouncer.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnGLS7pEDW1aAFeT2CLfH3yx2OVGFPfZdxpx86KJpIU\n";
  home.file.".ssh/hostinger.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJB31gq6Jv0QwEOs23AGjAif3i7wkTtrXi/jf2BXxoW\n";
  home.file.".ssh/pve.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4u1ArDc1SCrmA3qLBVmTQY353v69n2D/XuOLRB76e8\n";
  home.file.".ssh/services.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5AgLM722FbpRbHzI9GpD/6Vpzw8V80Ga+d8LAp+TWr\n";
  home.file.".ssh/fleet.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/MUIwp9waFBtjQmgxVQLLMRDlLMqLzUA5gxvIOTqi4\n";

  programs.ssh = {
    enable = true;

    # Home-manager's implicit `Host *` defaults are being removed upstream;
    # opt out and set the ones we want ourselves to silence the warning.
    enableDefaultConfig = false;

    settings = {
      "*" = {
        # No agent by default. Only the hosts listed below whose private key
        # actually lives in Bitwarden opt in, so an ad-hoc `ssh somewhere-else`
        # never offers identities to (or wakes) the Bitwarden agent.
        IdentityAgent = "none";

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

      # These three keys live only on disk, not in Bitwarden, so they inherit
      # the agent-free default from Host * above and read the file directly.
      # Forgejo is setup like this, so octarine can use Forgejo
      "10.1.2.155" = {
        HostName = "10.1.2.155";
        User = "git";
        IdentityFile = "~/.ssh/forgejo.key";
        IdentitiesOnly = true;
      };

      "10.2.2.143" = {
        Hostname = "10.1.2.143";
        User = "mani";
      };

      "10.1.2.119" = {
        HostName = "10.1.2.119";
        User = "ubuntu";
        IdentityFile = "~/.ssh/hermes.key";
        IdentitiesOnly = true;
      };

      # The hosts below authenticate with keys whose private half exists only in
      # Bitwarden — the IdentityFile is the public key, and the signature has to
      # come from the agent. These are the only entries that opt into it.
      halo = {
        HostName = "10.1.3.246";
        User = "mani";
        IdentityFile = "~/.ssh/halo.pub";
        IdentitiesOnly = true;
        IdentityAgent = bitwardenAgent;
      };

      # No Bitwarden key yet — password auth, so it keeps the agent-free default.
      ajwa = {
        HostName = "10.1.2.182";
        User = "mani";
      };

      hostinger = {
        HostName = "195.35.22.19";
        User = "mani";
        IdentityFile = "~/.ssh/hostinger.pub";
        IdentitiesOnly = true;
        IdentityAgent = bitwardenAgent;
      };

      pve = {
        HostName = "10.1.2.99";
        User = "root";
        IdentityFile = "~/.ssh/pve.pub";
        IdentitiesOnly = true;
        IdentityAgent = bitwardenAgent;
      };

      bouncer = {
        HostName = "10.1.2.10";
        User = "mani";
        IdentityFile = "~/.ssh/bouncer.pub";
        IdentitiesOnly = true;
        IdentityAgent = bitwardenAgent;
      };


      fleet = {
        HostName = "10.1.2.144";
        User = "ubuntu";
        IdentityFile = "~/.ssh/fleet.pub";
        IdentitiesOnly = true;
        IdentityAgent = bitwardenAgent;
      };
      services = {
        HostName = "10.1.2.102";
        User = "mani";
        IdentityFile = "~/.ssh/services.pub";
        IdentitiesOnly = true;
        IdentityAgent = bitwardenAgent;
      };
    };
  };
}
