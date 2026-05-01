#!/usr/bin/env python3
"""syncp.py — KeePass vault backup pipeline.

What this script does, in order:
  1. Sanity-checks: secret is loaded, KeePass DB exists, local Borg repo
     directory exists.
  2. Acquires a single-instance lock so two timer firings can't overlap.
  3. `borg create`     — snapshot the KeePass DB into the local repo.
  4. `borg prune`      — enforce the daily/weekly/monthly retention policy.
  5. `borg compact`    — actually reclaim the disk space that prune freed.
  6. Network probe     — if offline, stop here with success (local snapshot
                         is the important part; cloud is redundancy).
  7. `rclone sync`     — mirror the local repo to each cloud remote.

Designed to run unattended via a systemd timer. The systemd unit (kept
locally, not in this repo) loads BORG_PASSPHRASE through systemd's
LoadCredential= so the secret never sits in the unit environment in
plaintext; the script reads BORG_PASSCOMMAND, which Borg supports
natively.

The same pattern applies to the rclone configuration passphrase once
`rclone.conf` is encrypted (it is, because the config is now shared
across machines via Syncthing — see syncthing/README.md). The unit
loads the passphrase via a second LoadCredential= line and exposes it
to rclone through RCLONE_PASSWORD_COMMAND, rclone's native equivalent
of BORG_PASSCOMMAND. We pre-flight check for it before calling rclone.

Exit codes — chosen so the systemd OnFailure= handler only fires when
something actually went wrong:
  0  — every step succeeded, or cloud sync was skipped because we're offline.
  1  — a *local* step failed: missing config, snapshot, prune, or compact.
  2  — local steps succeeded but at least one cloud remote failed.
  3  — another instance is already running (lock held).
"""

# `from __future__ import annotations` makes every type annotation a
# string, evaluated lazily. That lets us use modern syntax like
# `int | None` and `list[str]` without caring which Python minor version
# the systemd unit ends up running under.
from __future__ import annotations

import fcntl  # File-locking via flock(2) for the single-instance guard.
import logging  # Structured, level-tagged output instead of bare print().
import os  # Environment lookups and low-level open() for the lock fd.
import socket  # Tiny TCP probe to decide if cloud sync is worth attempting.
import subprocess  # Drive the external `borg` and `rclone` binaries.
import sys  # sys.exit() with a meaningful return code; stdout/stderr handles.
from datetime import datetime  # Timestamp the archive name.
from pathlib import Path  # Tilde-expansion and OS-agnostic path handling.
from typing import Sequence  # Annotation for the run() helper's cmd argument.

# --- Configuration -----------------------------------------------------------

# Local Borg repository. Must already be initialised (`borg init`) and
# writable by whoever the systemd unit runs as. Borg refuses to operate
# on a non-existent path with a confusing error, so we also check this
# explicitly in sync() before doing anything else.
LOCAL_REPO = Path("~/keepass-backups").expanduser()

# The single file we are backing up. Stored deduplicated and encrypted
# inside LOCAL_REPO by Borg.
KEEPASS_DB = Path("~/vault/Vault.kdbx").expanduser()

# rclone remote names (configured via `rclone config`). Each remote
# receives a full mirror of LOCAL_REPO under `BorgBackup/`. Tuple, not
# list — this is configuration, not state, so it shouldn't be mutable.
REMOTES = ("gdrive", "mgdrive", "onedrive")

# Archive name for this run, e.g. "keepass-2026-04-27T10-42-11".
# Note the dashes in the time portion: ISO 8601 uses colons, but colons
# in archive names are awkward to grep/quote on the shell, and we'd
# rather format-loss-of-purity than format-loss-of-ergonomics here.
# Evaluated at import time → one consistent name even if `sync()` were
# somehow called twice in the same process.
ARCHIVE_NAME = "keepass-" + datetime.now().strftime("%Y-%m-%dT%H-%M-%S")

# Single-instance lock file. XDG_RUNTIME_DIR is a per-user, tmpfs-backed
# directory that systemd cleans up on logout — exactly the right scope
# for "is another run live right now?". Fall back to /tmp on the rare
# system where the variable isn't set (e.g. running this from a cron job
# that doesn't inherit the user manager's environment).
_RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
LOCK_FILE = _RUNTIME_DIR / "syncp.lock"

# Per-command timeouts in seconds. The point isn't tight bounds — it's
# to guarantee that *something* will eventually fail rather than the
# unit hanging forever on a wedged network or a stuck NFS mount.
BORG_TIMEOUT = 30 * 60  # 30 min — purely local I/O, generous.
RCLONE_TIMEOUT = 2 * 60 * 60  # 2 h — bounded by upstream bandwidth.

# Loose ceiling on `rclone sync` deletions. The *primary* "did the repo
# get wiped?" guard is repo_looks_healthy() below, which knows what a
# Borg repo is supposed to look like. This cap is just belt-and-braces:
# even if that check were bypassed, rclone would refuse to delete more
# than this many files in a single run.
#
# Set well above the worst-case routine churn — `borg compact` after a
# big prune can free several hundred segment files in one shot. Earlier
# versions used 50 here and tripped on the very first real run.
RCLONE_MAX_DELETE = 1000

# Minimum file count for LOCAL_REPO to be considered healthy. A
# legitimate Borg repo always has at least the layout files (config,
# nonce, README, hints/index/integrity for each segment) plus a `data/`
# tree of chunk files. Even a one-archive repo sits comfortably above
# this floor; "0 or 1 files" means something has truncated the repo.
REPO_MIN_FILES = 10

# Network probe target. We use a TCP connect to Cloudflare's DNS over
# 443 because:
#   - 1.1.1.1 has near-100 % global reachability when there's any net at all,
#   - port 443 is the most likely to be allowed through hotel/captive portals,
#   - a TCP connect (no DNS, no HTTP) is the cheapest possible "are we online?".
NETWORK_PROBE_HOST = "1.1.1.1"
NETWORK_PROBE_PORT = 443
NETWORK_PROBE_TIMEOUT = (
    5  # seconds — long enough for slow links, short enough not to stall.
)

# Exit codes. Named constants so callers (and the systemd OnFailure=
# handler) can reason about them without staring at magic numbers.
EXIT_OK = 0
EXIT_LOCAL_FAILURE = 1
EXIT_REMOTE_FAILURE = 2
EXIT_LOCKED = 3

# Module-level logger. Configured in configure_logging() at startup;
# every helper grabs this same instance.
log = logging.getLogger("syncp")


# --- Logging -----------------------------------------------------------------


def configure_logging() -> None:
    """Send INFO/DEBUG to stdout and WARNING+ to stderr.

    journald captures both streams from a systemd unit, but tagging by
    stream lets `journalctl --user -u syncp -p warning` filter for
    actionable lines only — useful when you're debugging at 11pm and
    don't want to scroll past kilobytes of routine sync output.
    """
    # SYNCP_LOG_LEVEL lets us crank verbosity without editing the unit:
    # `systemctl --user edit syncp.service` to drop in a one-liner override.
    level = os.environ.get("SYNCP_LOG_LEVEL", "INFO").upper()
    fmt = logging.Formatter("%(levelname)s %(message)s")

    # stdout handler: everything below WARNING. Filter, not setLevel,
    # because setLevel only sets a *minimum* — we want a maximum here.
    out = logging.StreamHandler(sys.stdout)
    out.setLevel(logging.DEBUG)
    out.addFilter(lambda r: r.levelno < logging.WARNING)
    out.setFormatter(fmt)

    # stderr handler: WARNING and above. setLevel is enough — there's no
    # ceiling we want to enforce on the error stream.
    err = logging.StreamHandler(sys.stderr)
    err.setLevel(logging.WARNING)
    err.setFormatter(fmt)

    log.setLevel(level)
    log.addHandler(out)
    log.addHandler(err)


# --- Helpers -----------------------------------------------------------------


def _to_str(x: object) -> str:
    """Coerce a stdout/stderr fragment to ``str``.

    ``subprocess.TimeoutExpired.{stdout,stderr}`` are typed
    ``bytes | str | None`` in the stubs regardless of whether the call
    that raised used ``text=True``. We always pass ``text=True``, so in
    practice it's ``str | None`` at runtime — but we still defend
    against bytes here, both because it satisfies every type checker
    without a ``cast``, and because if a future caller ever forgets
    ``text=True`` we'd rather log replacement chars than crash.
    """
    if isinstance(x, str):
        return x
    if isinstance(x, (bytes, bytearray)):
        return x.decode("utf-8", errors="replace")
    return ""


def run(
    cmd: Sequence[str | os.PathLike[str]],
    *,
    timeout: int,
) -> subprocess.CompletedProcess[str]:
    """Run a subprocess with captured output and a hard timeout.

    Centralising this means timeout handling, output capture, and the
    "oh you forgot text=True again" footgun all happen in one place.

    On timeout we don't raise — instead we synthesize a CompletedProcess
    with rc=124 (the conventional `timeout(1)` exit code). Callers can
    then handle "timed out" identically to "command failed", which
    matches what we actually want: complain and move on.
    """
    # Stringify only for the log line; subprocess accepts PathLike directly.
    log.debug("running: %s", " ".join(str(c) for c in cmd))
    try:
        return subprocess.run(
            list(cmd),
            capture_output=True,  # we want both streams in the result
            text=True,  # decode stdout/stderr as str, not bytes
            timeout=timeout,  # raises TimeoutExpired if exceeded
            check=False,  # caller inspects returncode itself
            # env=None (default) → inherit the parent environment, which
            # is where systemd has put BORG_PASSCOMMAND for us.
        )
    except subprocess.TimeoutExpired as exc:
        # Build a CompletedProcess so the rest of the code can treat
        # "timed out" exactly like "exited non-zero". Append a marker to
        # stderr so the journald log makes the cause obvious.
        # _to_str() handles the bytes|str|None typing on exc.{stdout,stderr}.
        stdout = _to_str(exc.stdout)
        stderr = _to_str(exc.stderr) + f"\n[timed out after {timeout}s]"
        return subprocess.CompletedProcess[str](
            args=list(cmd),
            returncode=124,
            stdout=stdout,
            stderr=stderr,
        )


def acquire_lock() -> int | None:
    """Take an exclusive non-blocking flock on LOCK_FILE.

    Returns the file descriptor on success, or None if the lock is held
    by another process (in which case we exit cleanly rather than
    queueing up).

    Why flock and not a "is the pidfile present?" check: flock is
    automatically released when the process dies for *any* reason —
    crash, kill -9, OOM. Stale pidfiles are an entire class of bug we
    don't want.
    """
    # 0o600: only the running user should ever read this lock file.
    fd = os.open(LOCK_FILE, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        # LOCK_NB → don't block; raise OSError if we can't get it.
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        # Someone else holds it. Close our fd so we don't leak it, and
        # signal "locked" to the caller.
        os.close(fd)
        return None
    return fd


def release_lock(fd: int) -> None:
    """Release the flock and close the fd. Idempotent on close errors."""
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        # Close even if unlock raised — the kernel releases the lock on
        # close anyway, so this is belt-and-braces.
        os.close(fd)


def repo_looks_healthy() -> bool:
    """Sanity-check LOCAL_REPO before we let rclone propagate its state.

    The real risk we're hedging against is "something truncated/wiped
    LOCAL_REPO and now `rclone sync` is about to mirror that empty state
    to all three cloud accounts, taking the offsite copies with it."

    We catch that with two cheap checks:
      1. The Borg layout marker files exist (`config`, `data/`).
      2. The total file count is at least REPO_MIN_FILES.

    Both fire on a wiped/truncated repo; neither fires on routine
    operation, no matter how aggressive `borg compact` was.
    """
    if not (LOCAL_REPO / "config").is_file():
        log.error("repo health: %s/config missing — refusing cloud sync", LOCAL_REPO)
        return False
    if not (LOCAL_REPO / "data").is_dir():
        log.error("repo health: %s/data/ missing — refusing cloud sync", LOCAL_REPO)
        return False
    # rglob walks the whole tree, but the repo is small (KeePass DB →
    # tens to low-hundreds of files) so this is microseconds.
    file_count = sum(1 for _ in LOCAL_REPO.rglob("*"))
    if file_count < REPO_MIN_FILES:
        log.error(
            "repo health: only %d entries under %s (< %d) — refusing cloud sync",
            file_count, LOCAL_REPO, REPO_MIN_FILES,
        )
        return False
    return True


def network_up() -> bool:
    """TCP-connect probe to decide whether cloud sync is worth attempting.

    Returns True if we can open a TCP connection to NETWORK_PROBE_HOST:PORT
    within NETWORK_PROBE_TIMEOUT seconds; False otherwise (logged at WARN).

    Why we bother: on a laptop on a plane / in a tunnel / behind a
    captive portal, every rclone call would chew through its full
    timeout before failing. A 5-second probe up front lets us short-circuit.
    """
    try:
        # Context-managed so the socket is closed even on early return.
        with socket.create_connection(
            (NETWORK_PROBE_HOST, NETWORK_PROBE_PORT),
            timeout=NETWORK_PROBE_TIMEOUT,
        ):
            return True
    except OSError as exc:
        # OSError covers DNS failures, connection refused, timeout, etc.
        log.warning("network probe failed (%s); skipping cloud sync", exc)
        return False


def borg_secret_present() -> bool:
    """True if Borg has *some* way to obtain the repo passphrase.

    Borg accepts BORG_PASSPHRASE (literal) *or* BORG_PASSCOMMAND (a shell
    command whose stdout is the passphrase). The systemd unit uses the
    latter so the secret only ever lives in $CREDENTIALS_DIRECTORY,
    never in the unit file or environment dump.
    """
    return bool(os.environ.get("BORG_PASSPHRASE") or os.environ.get("BORG_PASSCOMMAND"))


def rclone_secret_present() -> bool:
    """True if rclone has *some* way to obtain the config passphrase.

    Mirrors borg_secret_present() exactly — same threat model, same
    LoadCredential= pattern in the systemd unit. rclone accepts
    RCLONE_CONFIG_PASS (literal) *or* RCLONE_PASSWORD_COMMAND (a shell
    command whose stdout is the passphrase). The unit uses the latter
    so the secret only ever lives in $CREDENTIALS_DIRECTORY.

    We need this only when we're about to call rclone — `borg`-only
    runs (e.g. on a machine that's offline) don't require it. Hence
    sync() checks this *after* network_up() returns True, not in the
    top-level pre-flight block.
    """
    return bool(
        os.environ.get("RCLONE_CONFIG_PASS")
        or os.environ.get("RCLONE_PASSWORD_COMMAND")
    )


# --- Pipeline steps ----------------------------------------------------------


def borg_create() -> bool:
    """Snapshot KEEPASS_DB into LOCAL_REPO. Returns True on success."""
    log.info("creating snapshot %s", ARCHIVE_NAME)
    result = run(
        # `--stats` makes borg print dedup ratio and snapshot size to
        # stderr at the end of the run. Cheap, and very useful when
        # debugging "why is my repo growing so fast?" months from now.
        ["borg", "create", "--stats", f"{LOCAL_REPO}::{ARCHIVE_NAME}", KEEPASS_DB],
        timeout=BORG_TIMEOUT,
    )
    if result.returncode == 0:
        # Surface the stats to journald so they're searchable later.
        # Yes, success-stats land on stderr — that's a Borg quirk, not
        # ours, and we already capture both streams.
        if result.stderr.strip():
            log.info("snapshot stats:\n%s", result.stderr.strip())
        return True
    log.error(
        "borg create failed (rc=%d): %s", result.returncode, result.stderr.strip()
    )
    return False


def borg_prune() -> bool:
    """Enforce retention: 7 daily, 4 weekly, 6 monthly archives kept."""
    log.info("pruning local repo")
    result = run(
        [
            "borg",
            "prune",
            "--keep-daily=7",  # last week's worth of dailies
            "--keep-weekly=4",  # last month's worth of weeklies
            "--keep-monthly=6",  # last half-year of monthlies
            LOCAL_REPO,
        ],
        timeout=BORG_TIMEOUT,
    )
    if result.returncode == 0:
        return True
    log.error("borg prune failed (rc=%d): %s", result.returncode, result.stderr.strip())
    return False


def borg_compact() -> bool:
    """Reclaim the disk space `prune` freed.

    Important detail people miss: as of Borg 1.2, `prune` only marks
    chunks for deletion. The on-disk repo size doesn't shrink — and so
    rclone keeps shipping the same bytes — until `compact` actually
    removes them. Skipping this step is what makes "why is my cloud
    backup 80 GB for a 5 MB password file?" happen.
    """
    log.info("compacting local repo")
    result = run(["borg", "compact", LOCAL_REPO], timeout=BORG_TIMEOUT)
    if result.returncode == 0:
        return True
    log.error(
        "borg compact failed (rc=%d): %s", result.returncode, result.stderr.strip()
    )
    return False


def rclone_mirror(remote: str) -> bool:
    """Mirror LOCAL_REPO → `remote:BorgBackup`. Returns True on success."""
    log.info("rclone sync → %s:BorgBackup", remote)
    result = run(
        [
            "rclone",
            "sync",
            # --transfers / --checkers: parallelism knobs. 4/8 is rclone's
            # default-ish for small-file repos and works fine here; tune
            # higher if you ever back up something with thousands of files.
            "--transfers=4",
            "--checkers=8",
            # --fast-list trades a little RAM for far fewer API calls,
            # which matters on Google Drive in particular (per-second
            # rate limits, listed-files quotas).
            "--fast-list",
            # Safety cap — see RCLONE_MAX_DELETE comment above.
            f"--max-delete={RCLONE_MAX_DELETE}",
            LOCAL_REPO,
            f"{remote}:BorgBackup",
        ],
        timeout=RCLONE_TIMEOUT,
    )
    # rclone writes transfer summaries to stderr regardless of success;
    # always log it so the journal records what moved.
    if result.stderr.strip():
        log.info("%s output: %s", remote, result.stderr.strip())
    if result.returncode == 0:
        return True
    log.error("sync to %s failed (rc=%d)", remote, result.returncode)
    return False


# --- Entry point -------------------------------------------------------------


def sync() -> int:
    """Drive the full pipeline once. Returns the process exit code."""

    # --- Pre-flight checks ---------------------------------------------------
    # Each of these would eventually be caught by borg/rclone with a
    # cryptic message; we'd rather fail fast and clearly.
    if not borg_secret_present():
        log.error("BORG_PASSPHRASE / BORG_PASSCOMMAND not set; refusing to run")
        return EXIT_LOCAL_FAILURE

    if not KEEPASS_DB.is_file():
        log.error("KeePass DB not found at %s", KEEPASS_DB)
        return EXIT_LOCAL_FAILURE

    if not LOCAL_REPO.is_dir():
        # If LOCAL_REPO doesn't exist, we *must* abort before rclone:
        # `rclone sync ./missing remote:dir` would silently wipe the remote.
        log.error("Borg repo dir not found at %s (run `borg init` first)", LOCAL_REPO)
        return EXIT_LOCAL_FAILURE

    # --- Single-instance guard -----------------------------------------------
    # A previous run still going is rare but possible (slow rclone +
    # daily timer). Refuse to start rather than racing on the repo.
    lock_fd = acquire_lock()
    if lock_fd is None:
        log.warning("another syncp run holds %s; exiting", LOCK_FILE)
        return EXIT_LOCKED

    try:
        # --- Local pipeline --------------------------------------------------
        # All three steps are required for a healthy local repo. Bail
        # immediately on the first failure — there's no point compacting
        # if the snapshot itself didn't land.
        if not borg_create():
            return EXIT_LOCAL_FAILURE
        if not borg_prune():
            return EXIT_LOCAL_FAILURE
        if not borg_compact():
            return EXIT_LOCAL_FAILURE

        # --- Cloud mirror ---------------------------------------------------
        # Last line of defence before we let `rclone sync` propagate the
        # local state to all three clouds. If LOCAL_REPO has been
        # truncated/corrupted between the lock-acquire above and now,
        # this is what stops us from wiping the offsite copies too.
        if not repo_looks_healthy():
            return EXIT_LOCAL_FAILURE

        if not network_up():
            # The local snapshot is the load-bearing step; cloud copies
            # are redundancy. Returning OK here means a flaky network on
            # a given day doesn't trigger the OnFailure= notifier — we'll
            # catch up the next time the timer fires with connectivity.
            log.info("offline — local snapshot retained, cloud sync deferred")
            return EXIT_OK

        # rclone.conf is encrypted (it's now Syncthing-shared across
        # machines), so rclone needs the passphrase. The systemd unit
        # supplies it via LoadCredential= + RCLONE_PASSWORD_COMMAND.
        # We check here rather than in the top-level pre-flight so
        # offline runs aren't penalised for a missing rclone secret —
        # they don't reach this code path. Failing fast and clearly
        # beats letting rclone error out three times with a cryptic
        # "couldn't decrypt config" line buried in transfer output.
        if not rclone_secret_present():
            log.error(
                "RCLONE_CONFIG_PASS / RCLONE_PASSWORD_COMMAND not set; "
                "refusing to call rclone against an encrypted config"
            )
            return EXIT_REMOTE_FAILURE

        # Try every remote, even if one fails — partial offsite redundancy
        # is better than none. Collect names for the summary line.
        failed = [r for r in REMOTES if not rclone_mirror(r)]
        if failed:
            log.error("cloud sync failed for: %s", ", ".join(failed))
            return EXIT_REMOTE_FAILURE

        log.info("all remotes synced")
        return EXIT_OK
    finally:
        # Always release the lock — including on uncaught exceptions —
        # so a crashed run doesn't wedge tomorrow's timer.
        release_lock(lock_fd)


if __name__ == "__main__":
    # Configure logging *before* sync() so even pre-flight failures get
    # the structured format and proper stream routing.
    configure_logging()
    sys.exit(sync())
