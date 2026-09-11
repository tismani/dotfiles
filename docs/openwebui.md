# Open WebUI state, backup, and migration

Halo runs Open WebUI as a native NixOS service. The Nix expression defines how
the service runs, while accounts, chats, settings, uploads, and credentials live
outside the Nix store. Migrating the Git checkout alone is therefore not enough.

## Where everything lives

| Purpose | Path | Back up? |
| --- | --- | :---: |
| Declarative service configuration | `hosts/halo/llm.nix` | yes, through Git |
| Open WebUI state root | `/var/lib/open-webui` | yes |
| SQLite database | `/var/lib/open-webui/data/webui.db` | yes |
| Uploads, knowledge data, and vector indexes | `/var/lib/open-webui/data/` | yes |
| Model and transformer caches | `/var/lib/open-webui/hf_home/` and `/var/lib/open-webui/transformers_home/` | optional, but included below |
| LiteLLM master key | `/var/lib/litellm/environment` | yes for a complete migration |
| Open WebUI's LiteLLM key and session secret | `/var/lib/litellm/open-webui-environment` | yes |
| Service logs | systemd journal | normally no |

`/var/lib/open-webui` is the stable, logical path to use. Because the NixOS
service uses systemd's `DynamicUser`, it may be a symlink to
`/var/lib/private/open-webui`. Do not hard-code the private path; resolve the
logical path with `readlink -f` when backing up or restoring it.

The two files under `/var/lib/litellm` are mode `0600` secrets. The second file
contains both `OPENAI_API_KEY`, which authenticates Open WebUI to LiteLLM, and
`WEBUI_SECRET_KEY`, which signs Open WebUI sessions and may be used to derive
encryption keys. Never commit either file or place an unencrypted copy in public
or shared storage.

Open WebUI stores many environment-backed settings in `webui.db` after its first
start. Consequently, changes made later to `OPENAI_API_BASE_URL` in the Nix file
may be superseded by the value saved in the database. Change an existing
instance's connection under **Admin Settings > Connections**, or deliberately
reset its persistent configuration. See the upstream
[environment-variable reference](https://docs.openwebui.com/reference/env-configuration/)
before resetting it.

## Inspect the current instance

These commands do not modify the service:

```sh
systemctl status open-webui litellm --no-pager
systemctl cat open-webui
readlink -f /var/lib/open-webui
sudo find "$(readlink -f /var/lib/open-webui)" \
  -maxdepth 2 -mindepth 1 -printf '%p\n' | sort
sudo awk -F= '{ print $1 "=<redacted>" }' \
  /var/lib/litellm/environment \
  /var/lib/litellm/open-webui-environment
```

Open WebUI is configured to listen on port 8080 and to use LiteLLM at
`http://127.0.0.1:4000/v1`. It is reachable locally at
`http://127.0.0.1:8080` and over Halo's trusted NetBird interface. Port 8080 is
not opened on other firewall interfaces.

## Create a complete backup

Stop Open WebUI while copying its state. This gives SQLite a consistent chance
to checkpoint its write-ahead log, as recommended by the upstream
[database export guide](https://docs.openwebui.com/tutorials/maintenance/database/).
LiteLLM may remain running.

Run the following from a directory on a disk with enough free space:

```sh
BACKUP_DIR="$PWD/openwebui-backup-$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$BACKUP_DIR"

sudo systemctl stop open-webui

OPENWEBUI_STATE="$(readlink -f /var/lib/open-webui)"
case "$OPENWEBUI_STATE" in
  /var/lib/open-webui|/var/lib/private/open-webui) ;;
  *) printf 'Unexpected Open WebUI state path: %s\n' "$OPENWEBUI_STATE" >&2; exit 1 ;;
esac

sudo tar --acls --xattrs -C "$OPENWEBUI_STATE" \
  -czf "$BACKUP_DIR/openwebui-state.tar.gz" .
sudo install -m 0600 /var/lib/litellm/environment \
  "$BACKUP_DIR/litellm-environment"
sudo install -m 0600 /var/lib/litellm/open-webui-environment \
  "$BACKUP_DIR/open-webui-environment"
sudo chown -R "$(id -u):$(id -g)" "$BACKUP_DIR"

sudo systemctl start open-webui

(cd "$BACKUP_DIR" && \
  sha256sum litellm-environment open-webui-environment \
    openwebui-state.tar.gz > SHA256SUMS)
tar -tzf "$BACKUP_DIR/openwebui-state.tar.gz" \
  | sed -n '1,40p'
printf 'Backup written to %s\n' "$BACKUP_DIR"
```

Confirm that the archive listing contains `./data/webui.db`. The full archive
also includes uploads, vector indexes, generated content, and caches, so it may
be much larger than the database alone. The upstream
[backup guide](https://docs.openwebui.com/tutorials/maintenance/backups/)
describes the contents of the persistent data directory.

Copy the entire backup directory to a different disk or host over an encrypted
channel. It contains conversations, uploaded documents, account data, and the
LiteLLM master key. Keep the dotfiles Git revision and `flake.lock` used by the
source host as well.

## Restore or migrate to another Halo installation

For the safest version-to-version migration, first deploy the same dotfiles
revision and `flake.lock` as the source machine. Restore the data, confirm it
works, and only then update Open WebUI. Its database migrations run at startup
and may not be reversible, so take another backup before upgrading.

On the destination, put the copied backup directory in `BACKUP_DIR`, deploy the
service once so systemd creates its state directories, and verify the checksums:

```sh
cd ~/dotfiles
sudo nixos-rebuild switch --flake .#halo

BACKUP_DIR=/path/to/openwebui-backup-YYYYMMDD-HHMMSS
cd "$BACKUP_DIR"
sha256sum -c SHA256SUMS
cd -
```

The following restore replaces the destination's Open WebUI state and LiteLLM
credentials. It first moves the destination state into a timestamped rollback
directory instead of deleting it. Only use this on the intended destination
host.

```sh
sudo systemctl stop open-webui litellm litellm-key

OPENWEBUI_STATE="$(readlink -f /var/lib/open-webui)"
case "$OPENWEBUI_STATE" in
  /var/lib/open-webui|/var/lib/private/open-webui) ;;
  *) printf 'Unexpected Open WebUI state path: %s\n' "$OPENWEBUI_STATE" >&2; exit 1 ;;
esac

ROLLBACK_DIR="/var/lib/openwebui-pre-restore-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 0700 "$ROLLBACK_DIR/state" "$ROLLBACK_DIR/credentials"
sudo find "$OPENWEBUI_STATE" -mindepth 1 -maxdepth 1 \
  -exec mv -t "$ROLLBACK_DIR/state" -- {} +

for secret in environment open-webui-environment; do
  if sudo test -f "/var/lib/litellm/$secret"; then
    sudo cp -a "/var/lib/litellm/$secret" "$ROLLBACK_DIR/credentials/"
  fi
done

sudo tar --acls --xattrs --no-same-owner \
  -xzf "$BACKUP_DIR/openwebui-state.tar.gz" \
  -C "$OPENWEBUI_STATE"
sudo chown -R --reference="$OPENWEBUI_STATE" "$OPENWEBUI_STATE"/.

sudo install -o root -g root -m 0600 \
  "$BACKUP_DIR/litellm-environment" \
  /var/lib/litellm/environment
sudo install -o root -g root -m 0600 \
  "$BACKUP_DIR/open-webui-environment" \
  /var/lib/litellm/open-webui-environment

sudo systemctl start litellm-key
sudo systemctl start litellm open-webui
```

Preserving `/var/lib/litellm/environment` keeps the LiteLLM master key that is
already saved in Open WebUI's database. If the destination has an established
LiteLLM deployment whose existing key must remain unchanged, do not overwrite
that file. Restore `open-webui-environment`, restart `litellm-key` so it inserts
the destination key, and then update the saved LiteLLM connection key in Open
WebUI's Admin Settings after logging in.

## Verify the restored service

Check the services, the UI endpoint, model discovery, and recent logs:

```sh
systemctl status litellm open-webui --no-pager
curl --fail --silent http://127.0.0.1:8080/api/config | jq

sudo sh -c '
  key=$(sed -n "s/^LITELLM_MASTER_KEY=//p" /var/lib/litellm/environment)
  curl --fail --silent http://127.0.0.1:4000/v1/models \
    -H "Authorization: Bearer $key"
' | jq -r '.data[].id' | sort

journalctl -u litellm -u open-webui -b --no-pager -n 200
```

Log in with an existing account and confirm that chats, uploaded documents, and
knowledge collections are present. If the service reports a database migration
error, stop it and restore the pre-migration backup rather than trying to run
manual SQL immediately. The upstream
[manual migration guide](https://docs.openwebui.com/troubleshooting/manual-database-migration/)
recommends manual intervention only for specific migration failures.

After the restored instance has been verified, the rollback directory shown by
the restore command can be archived elsewhere or removed manually. Keep it until
both Open WebUI login and LiteLLM model calls have been tested.

## Chat-only export is not a complete backup

Open WebUI's **Settings > Data Controls > Export Chats** feature is useful for
moving conversation history between accounts, but it does not replace the
filesystem backup above. It does not capture the complete instance state,
credentials, uploads, or every administrator setting. Use it only when chats
are the sole data that needs to move.
