{ pkgs, lib, ... }:

{
  # CLI for editing secrets/*.yaml and deriving host recipients from SSH keys.
  environment.systemPackages = with pkgs; [ sops age ssh-to-age ];

  # NixOS hosts decrypt with their SSH host key (converted to age at
  # activation), so no separate key file has to be provisioned on the host.
  sops.age.sshKeyPaths = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin)
    [ "/etc/ssh/ssh_host_ed25519_key" ];
}
