# syncthing — folder inventory and conventions

This directory documents every Syncthing folder we run across our
devices, plus the per-folder ignore patterns (`*.stignore`) that govern
what actually crosses the wire.

Syncthing itself is configured per-device via its own GUI/REST API —
folder IDs, share state, and per-device paths live in each device's
`config.xml` (`~/.local/state/syncthing/` on Linux,
`~/Library/Application Support/Syncthing/` on macOS, the app's internal
storage on Android). This repo holds only the *intent*: which folders
exist, what they're for, who has them, and what to ignore inside them.

The `.stignore` files in this directory must be copied (or symlinked)
into the matching folder on each device — Syncthing reads `.stignore`
from the *folder root*, not from a central config. Recommended layout:
keep this `syncthing/` directory checked out somewhere, then on each
device run e.g. `ln -s ~/projects/oci/syncthing/vault.stignore
~/vault/.stignore`. Symlinks survive Syncthing edits to the file
because Syncthing rewrites in place rather than replacing the inode.

---

## Topology

The OCI ARM64 instance (`oci`) is the always-on hub:

  - It is configured as a **Syncthing introducer** — when a new device
    is added to OCI's known-devices list and shares a folder, every
    other peer on that folder learns about the new device automatically.
    No O(N²) pasting of device IDs.
  - It runs 24/7, so phone-only edits (e.g. KeePassXC on Android adding
    a new entry) propagate to laptops even when both laptops are off.
  - It holds the canonical replica that the `syncp.py` backup pipeline
    snapshots into Borg and mirrors to the cloud remotes.

Daily-driver peers:
  - **Mac** (laptop, intermittent)
  - **Arch** (desktop / laptop, intermittent)
  - **Pixel** (phone, mostly online but on cellular)

Other peers can be added later (family Android phones for the eventual
Immich rollout, etc.) — the introducer setup means we only have to
share with OCI and folders propagate.

---

## Conventions

**Where folder data lives on each peer.** Tiny configs sync to their
natural locations (e.g. `~/.config/rclone/` because that's where
rclone looks). Bulk data — anything that could grow into the
multi-GiB range (photos, downloads, archives) — goes under
`/mnt/cloud-storage/syncthing/<folder>/` on OCI, which is the dedicated
150 GiB volume. There is no point putting a 4 KiB config on a separate
mount.

**Folder IDs.** Syncthing folder IDs are arbitrary strings shared
across peers; once set, they never change. Use short kebab-case names
that match the directory in this repo (e.g. `vault`, `rclone-config`).
The vault folder predates this README and keeps whatever ID it already
has — don't re-create it.

**Send/Receive mode.** Default to *Send & Receive* on every peer
unless there's a specific reason not to. KeePassXC and rclone are both
edited from multiple devices, so single-master modes would cause data
loss. The OCI hub is also Send & Receive — making it a pure mirror
would mean phone-only edits couldn't propagate while a laptop is off,
defeating the point of the always-on box.

**Ignore patterns.** Two styles, picked per folder:
  - **Denylist** (vault) — list the known-bad transient files. Right
    when the folder has a fixed, well-understood set of files and you
    want any *new* files to sync by default.
  - **Allowlist** (rclone-config) — exclude `*` then re-include only
    the specific files you want. Right when the directory is shared
    with other tools that may drop unrelated files (token caches, OS
    metadata) you don't want crossing the network.

---

## Folder: `vault`

**Purpose.** Sync the KeePassXC database (`Vault.kdbx`) across all
personal devices so password edits made anywhere appear everywhere.
KeePassXC handles concurrent merges natively when two devices edit
while offline.

**Paths per device.**
  - Mac:   `~/vault/`
  - Arch:  `~/vault/`
  - Pixel: `phonestorage/vault/` (the app surfaces this as
           `/storage/emulated/0/vault/`)
  - OCI:   `~/vault/` (matching `syncp.py`'s `KEEPASS_DB` path —
           the backup pipeline reads from this exact location)

**Contents.** Exactly one file: `Vault.kdbx`. Anything else that
appears alongside it is transient (locks, journals, on-save backups).

**Ignore file.** `vault.stignore` — denylist of KeePassXC's transient
files. See that file for line-by-line rationale.

**Conflict handling.** KeePassXC merges automatically on next open
when it detects a divergent timestamp; in the rare case Syncthing
records a `*.sync-conflict-*` file, open both copies in KeePassXC,
use Database → Merge From Database, and delete the conflict file.

**Backup.** `syncp.py` (running as a systemd timer on OCI) snapshots
this file into a local Borg repo, prunes/compacts, and mirrors to
three cloud remotes via rclone. That pipeline is the source of truth
for *historical* vault state — Syncthing only carries the current
version.

---

## Folder: `rclone-config`

**Purpose.** Sync rclone's configuration file across daily-driver
machines so a remote added on one laptop is immediately usable from
the other (and from the OCI box, where `syncp.py` invokes rclone).

**Critical precondition.** `rclone.conf` holds OAuth tokens, refresh
tokens, and access keys for every cloud remote. **Encrypt it before
syncing**: on any machine that already has the populated config, run
`rclone config` → `s` (Set configuration password) → enter a strong
passphrase. The same passphrase will be required on every machine
that reads the config (interactively for `rclone` CLI use; via
`RCLONE_PASSWORD_COMMAND` for `syncp.py`'s unattended runs — see
"systemd integration" below).

**Paths per device.**
  - Mac:   `~/.config/rclone/`
  - Arch:  `~/.config/rclone/`
  - OCI:   `~/.config/rclone/`
  - Pixel: not synced (no rclone on phone)

**Contents.** Exactly one file we care about: `rclone.conf`. The
ignore pattern is an allowlist — only that file crosses, even if
rclone or you happen to drop other things into the directory.

**Ignore file.** `rclone-config.stignore` — allowlist style. See file.

**Conflict handling.** Rare in practice (config edits are infrequent
and sequential), but if Syncthing records a `*.sync-conflict-*` file,
open both in a text editor, manually merge any new `[remote]`
sections, and delete the loser.

---

## Adding a new folder

Template for the next addition (Thunderbird, Obsidian vault, dotfiles,
whatever comes next):

1. **Decide path per device.** Pick the natural location on each peer.
   For OCI, use `~/<name>/` if small, `/mnt/cloud-storage/syncthing/<name>/`
   if it could grow.
2. **Create the folder on OCI first**, then add it in OCI's Syncthing
   UI with a memorable folder ID. Share it with each peer device.
3. **On each peer**, accept the share offer in Syncthing, set the
   per-device path, and choose Send & Receive (unless there's a
   reason not to).
4. **Add `<name>.stignore` to this directory.** Heavy comments
   explaining what each pattern is for and *why* — future-you will
   thank present-you.
5. **Symlink the stignore into the folder root** on each device:
   `ln -s ~/projects/oci/syncthing/<name>.stignore <folder>/.stignore`.
   Syncthing picks it up on the next scan.
6. **Document the new folder in this README** with the same section
   layout as `vault` and `rclone-config` above.

---

## systemd integration for the encrypted rclone config

`syncp.py` runs unattended on OCI and shells out to `rclone`. Once
`rclone.conf` is encrypted, rclone needs the passphrase. We use the
same `LoadCredential=` pattern already in place for `BORG_PASSPHRASE`
so the secret never sits in the unit environment in plaintext.

Add to the syncp `.service` unit (alongside the existing borg
credential lines):

```ini
[Service]
LoadCredential=rclone-passphrase:%h/.config/syncp/rclone-passphrase
Environment=RCLONE_PASSWORD_COMMAND=cat %d/rclone-passphrase
```

  - `LoadCredential=rclone-passphrase:<source>` — systemd reads the
    file at `<source>` once at unit start and exposes it inside the
    unit's private credentials directory. `<source>` should be a
    0600 file on the OCI box owned by the same user the unit runs as,
    containing only the rclone passphrase (no trailing newline is
    fine — `cat` will pass any newline through unchanged, and rclone
    is permissive about it).
  - `Environment=RCLONE_PASSWORD_COMMAND=cat %d/rclone-passphrase` —
    `%d` is systemd's specifier for `$CREDENTIALS_DIRECTORY`, the
    runtime path where `LoadCredential=` materialised the secret.
    Rclone runs this command and uses stdout as the config password.

After editing the unit:

```sh
systemctl --user daemon-reload
systemctl --user restart syncp.service
journalctl --user -u syncp.service -f   # watch the next run
```

`syncp.py` itself enforces this: a pre-flight check refuses to call
rclone if neither `RCLONE_CONFIG_PASS` nor `RCLONE_PASSWORD_COMMAND`
is in the environment, mirroring the existing `BORG_PASSPHRASE` /
`BORG_PASSCOMMAND` check.
