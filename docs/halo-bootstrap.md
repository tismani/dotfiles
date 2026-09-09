# Halo: bootstrap after a fresh install

Halo is the Framework Desktop AMD AI Max host (`x86_64-linux`), using NixOS,
UEFI/systemd-boot, GNOME, and user `mani` at `/home/mani`. Its entry point is
[`hosts/halo/configuration.nix`](../hosts/halo/configuration.nix), selected by
`nixosConfigurations.halo` in [`flake.nix`](../flake.nix).
Nix and Home Manager come with this system configuration; no Lix installer is needed.

## 1. Boot the installer

Download an x86_64 NixOS installer from the [official download page](https://nixos.org/download/),
write it to a USB drive, and boot it in UEFI mode. Use the following manual install
route to install this flake directly. Connect Ethernet or use the installer
desktop's network controls. Open a terminal and enter a root Bash shell:

```sh
sudo -i
bash
test -d /sys/firmware/efi && echo 'UEFI boot confirmed'
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,MOUNTPOINTS
```

If UEFI is not confirmed, reboot the USB in UEFI mode. The configuration does not
set up Secure Boot signing; use firmware settings that permit the NixOS bootloader.
The general installation procedure is covered in the
[NixOS installation guide](https://wiki.nixos.org/wiki/NixOS_Installation_Guide).

## 2. Prepare partitions and the required labels

[`hardware-configuration.nix`](../hosts/halo/hardware-configuration.nix) uses
**filesystem labels**, not UUIDs or GPT partition names:

| Use | Filesystem | Exact label | Configured device |
| --- | --- | --- | --- |
| `/` | ext4 | `nixos` | `/dev/disk/by-label/nixos` |
| `/boot` | FAT32 EFI system partition | `boot` | `/dev/disk/by-label/boot` |
| Swap | Linux swap partition | `swap` | `/dev/disk/by-label/swap` |

All three must exist before booting this config. Reformatting replaces labels;
reapply them on each reinstall. No encryption, Btrfs subvolumes, or swap file is
declared. Those layouts require changing the host configuration first.

### New disk / erase-and-reinstall route

Back up anything needed first. Partitioning and formatting below erase data on
the selected partitions. Identify the internal drive by model and size in
`lsblk`; do not assume the installer USB or another disk is the target.

Run `cfdisk /dev/nvme0n1`, replacing the device with your verified target. Create
a GPT layout with a 1 GiB EFI System partition, a Linux swap partition (choose
its size for your needs), and a Linux filesystem partition using the remaining
space. Write the table and quit. These sizes/order are an example, not encoded
in the repository. The config does not define a hibernation/resume setup.

Set these variables to the actual partitions shown by `lsblk` after partitioning:

```sh
EFI_PART=/dev/nvme0n1p1
SWAP_PART=/dev/nvme0n1p2
ROOT_PART=/dev/nvme0n1p3
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

Only after verifying those values and ensuring the partitions are unmounted:

```sh
mkfs.fat -F 32 -n boot "$EFI_PART"
mkswap -L swap "$SWAP_PART"
mkfs.ext4 -L nixos "$ROOT_PART"
```

### Existing compatible installation / relabel-only route

If NixOS is already installed with ext4 root, FAT EFI, and a swap partition,
boot the live USB and identify those partitions. Set the three variables above
to match the existing layout. Unmount the target root and EFI partitions using
their actual mountpoints shown by `lsblk`; disable the target swap with
`swapoff "$SWAP_PART"` if `swapon --show` lists it. Then change labels without
formatting:

```sh
e2label "$ROOT_PART" nixos
fatlabel "$EFI_PART" boot
swaplabel -L swap "$SWAP_PART"
```

Do not run `mkfs` or `mkswap` for this route. If retaining an installed system,
its generated config may still refer to UUIDs; the steps below explicitly install
this repository's configuration instead.

## 3. Mount and check the target

```sh
udevadm settle
blkid "$ROOT_PART" "$EFI_PART" "$SWAP_PART"
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/disk/by-label/swap
findmnt /mnt
findmnt /mnt/boot
swapon --show
```

Check that no other attached drive has the same labels. Duplicate labels make
`/dev/disk/by-label` ambiguous. The lowercase `boot` label is intentional; match
the repository's case exactly.

## 4. Put the repository on the target

From the installer root shell:

```sh
nix-shell -p git
mkdir -p /mnt/home/mani
git clone https://forgejo.internal.tismani.com/mani/dotfiles.git /mnt/home/mani/dotfiles
```

Forgejo requires internal DNS/network access and credentials. If unavailable,
copy a complete checkout from another machine or backup, including `.git` and
`flake.lock`, to `/mnt/home/mani/dotfiles`. If preserving a checkout already at
that path, use it instead of cloning over it. Keep the existing lock file.

For the same Halo hardware and the layout above, use the committed hardware
configuration. If hardware changed, generate a scan in a temporary location and
compare it; preserve the label-based filesystem entries when incorporating changes:

```sh
nixos-generate-config --root /mnt --dir /tmp/halo-hardware-scan
diff -u /mnt/home/mani/dotfiles/hosts/halo/hardware-configuration.nix \
  /tmp/halo-hardware-scan/hardware-configuration.nix
```

Differences in UUID-versus-label paths are expected. Do not overwrite the
repository's hardware file blindly. Any newly added Nix files must be `git add`ed
so the Git-backed flake can see them.

## 5. Restore the LiteLLM secret before first boot

The enabled LiteLLM service requires `/var/lib/secrets/litellm.env`. Restore a
backup there on the mounted target, or generate a new key in the root Bash shell:

```sh
install -d -m 0700 /mnt/var/lib/secrets
umask 077
key="sk-$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
printf 'LITELLM_MASTER_KEY=%s\n' "$key" > /mnt/var/lib/secrets/litellm.env
chmod 0600 /mnt/var/lib/secrets/litellm.env
printf 'Save this key in your password manager: %s\n' "$key"
unset key
umask 022
```

Use generation only when creating/replacing the key; it overwrites the file.
Synchronize a new key with Nightfury's Keychain and other clients as described in
[Halo LLM gateway setup](halo-llm.md). Keep the secret outside the repository.

## 6. Install, set passwords, and reboot

```sh
nixos-install --option experimental-features 'nix-command flakes' \
  --flake /mnt/home/mani/dotfiles#halo
```

The initial build includes the AMD GPU/NPU and LLM stack and can take substantial
time and disk space. Complete the installer root-password prompt. After a
successful install, set `mani`'s password explicitly: the config creates the
account but supplies no password or authorized SSH keys.

```sh
nixos-enter --root /mnt -c 'passwd mani'
nixos-enter --root /mnt -c 'chown -R mani:users /home/mani/dotfiles'
reboot
```

Remove the USB and boot the installed system. Home Manager was installed with
the system. Keep `system.stateVersion = "25.11"` and `home.stateVersion = "24.11"`
as configured; these are compatibility settings, not versions to bump on reinstall.

## 7. Finish account, networking, and model setup

Log in to GNOME as `mani`. Use Bash for the commands below (`bash` if necessary).

1. Check the installed mounts and desktop services:

   ```sh
   hostname
   findmnt /
   findmnt /boot
   swapon --show
   systemctl --failed
   systemctl status display-manager flatpak-add-flathub
   flatpak list
   ```

   Expect hostname `halo`, all three labeled filesystems, and GNOME. Niri is
   explicitly disabled. The boot service installs Vivaldi and Bitwarden from
   Flathub; if its network download failed, run
   `sudo systemctl restart flatpak-add-flathub` after connectivity is restored.
2. Enroll the machine in Tailscale with `sudo tailscale up`. If using NetBird,
   enroll it with `sudo netbird up`. Authentication and network memberships are
   not stored in Nix. Restore any DHCP reservation needed for `10.1.3.246`, or
   update the `halo` SSH entry in
   [`home/mani/programs/ssh.nix`](../home/mani/programs/ssh.nix).
3. Enable remote login by installing the trusted client public key. For the
   existing Bitwarden-held Halo identity, the managed public key can be used:

   ```sh
   install -d -m 0700 ~/.ssh
   cat ~/.ssh/halo.pub >> ~/.ssh/authorized_keys
   chmod 0600 ~/.ssh/authorized_keys
   ```

   Run this once as `mani`. On Nightfury, unlock Bitwarden and enable its SSH
   agent, then test `ssh halo` and `sudo -v` inside the session. After a reinstall,
   verify Halo's new host-key fingerprint locally with
   `sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` before replacing any old
   client known-host entry. The config enables SSH but does not deploy authorized keys.
4. Open Bitwarden on Halo and restore its account/SSH agent if using outgoing
   SSH. The expected socket is
   `~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock`. Restore any
   disk-only private keys separately; Nix supplies only the public keys.
5. Download models as `mani` (or restore `/var/lib/llm-models` from backup with
   ownership `mani:users`):

   ```sh
   llm-model-pull all
   systemctl status llama-swap litellm
   curl --fail http://127.0.0.1:9292/v1/models
   ```

   Model weights are not downloaded by installation. Follow
   [Halo LLM gateway setup](halo-llm.md) for the authenticated endpoint and clients.
   Port 4000 is opened only on `tailscale0`; LAN access is not enabled by this config.
6. Fish is configured but not selected as the login shell. Run `fish` to use the
   aliases, or, after checking its path in `/etc/shells`, run
   `chsh -s /run/current-system/sw/bin/fish` to select it.

## 8. Rebuild later

```sh
sudo nixos-rebuild switch --flake ~/dotfiles#halo
```

In Fish, `rebuild` applies the local host. From a configured
[Nightfury](nightfury-bootstrap.md), `rebuild-halo` builds and activates on Halo
over SSH and prompts for sudo authentication. Local configuration changes must
be present in the checkout used for that rebuild. Reboot after kernel changes.
If a new generation fails to boot, select the previous generation in systemd-boot;
wrong or missing filesystem labels must be corrected from the live USB.
