{ pkgs, ... }: {

  # Public half of the halo keypair; the private key lives only in Bitwarden.
  home.file.".ssh/halo.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrXTBSu8Qc25QC+4Y5Lk0mwzOlF9xTZBCKqjhpFYSRI\n";

  programs.ssh = {
    enable = true;
    settings = {
      # Bitwarden desktop app's SSH agent socket.
      # nightfury: Bitwarden installed via Mac App Store (sandboxed container path).
      # halo: Bitwarden installed via Flatpak.
      "*".IdentityAgent =
        if pkgs.stdenv.isDarwin
        then "~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
        else "~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";

      # These three keys live only on disk, not in Bitwarden. With a global
      # IdentityAgent configured, OpenSSH routes explicitly-configured
      # IdentityFile offers through the agent first ("explicit agent" in
      # `ssh -v`); since Bitwarden doesn't hold these keys, that silently
      # fails auth instead of falling back to reading the file directly.
      # IdentityAgent none keeps them on the old, working, agent-free path.
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

      hostinger = {
        HostName = "195.35.22.19";
        User = "mani";
        IdentityFile = "~/.ssh/hostinger.key";
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
    };
  };
}
