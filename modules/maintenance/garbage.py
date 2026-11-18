"""Plan and run Ember's system-profile maintenance."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


PROFILE = Path("/nix/var/nix/profiles/system")
SYSTEMS = {"booted": Path("/run/booted-system"), "active": Path("/run/current-system")}
LOCK = Path("/run/ember-nix-gc.lock")


def plan():
    current = PROFILE.readlink()
    identity = {}
    protected = {}
    running = {name: link.resolve(strict=True) for name, link in SYSTEMS.items()}
    for link in PROFILE.parent.iterdir():
        match = re.fullmatch(r"system-(\d+)-link", link.name)
        if not match or not link.is_symlink():
            continue
        number = int(match[1])
        target = link.resolve(strict=True)
        reasons = [name for name, system in running.items() if target == system]
        stat = link.lstat()
        identity[number] = [str(target), stat.st_ino, stat.st_mtime_ns]
        if PROFILE.parent / current == link or current == link:
            reasons.append("system profile")
        if reasons:
            protected[number] = reasons
    if not any("system profile" in reasons for reasons in protected.values()):
        raise ValueError("missing current generation")

    # Duplicate generations can point to the same running closure. Keep one
    # entry per closure plus the profile's selected entry, then fill newest-first.
    keep = {number for number, reasons in protected.items() if "system profile" in reasons}
    for name in running:
        matches = {number for number, reasons in protected.items() if name in reasons}
        if matches and not matches & keep:
            keep.add(max(matches))
    for number in sorted(identity, reverse=True):
        if len(keep) >= 5:
            break
        keep.add(number)
    remove = sorted(identity.keys() - keep)
    fingerprint = [str(current), {k: str(v) for k, v in running.items()}, identity, remove]
    token = hashlib.sha256(json.dumps(fingerprint, sort_keys=True).encode()).hexdigest()
    return keep, remove, protected, token


def format_ids(numbers):
    return ", ".join(map(str, sorted(numbers))) or "none"


def preview(snapshot):
    keep, remove, protected, token = snapshot
    labels = [f"{n} ({', '.join(protected[n])})" for n in sorted(keep & protected.keys())]
    print(f"Generations to keep: {format_ids(keep)}")
    if labels:
        print(f"Protected generations: {', '.join(labels)}")
    print(f"Generations to delete: {format_ids(remove)}")
    print("Cleanup also collects Nix store paths unreachable from any GC root.")
    return token


def boot_entries(esp):
    if not esp.is_mount():
        return "Mount the EFI system partition to check boot entries."
    entries = sorted((esp / "loader/entries").glob("nixos*.conf"))
    checked = 0
    stale = []
    for entry in entries:
        options = entry.read_text().splitlines()
        init = next(
            (item.removeprefix("init=") for line in options
             if line.split(maxsplit=1)[:1] == ["options"]
             for item in line.split()[1:] if item.startswith("init=/nix/store/")),
            None,
        )
        if init is None:
            continue
        checked += 1
        assets = [
            esp / parts[1].lstrip("/")
            for line in options if len(parts := line.split()) == 2
            and parts[0] in {"linux", "initrd"}
        ]
        if not Path(init).is_file() or not assets or any(not path.is_file() for path in assets):
            stale.append(entry.stem)
    if stale:
        return "Boot entries reference missing files: " + ", ".join(stale)
    if not checked:
        return "No NixOS boot entries were available to check."
    return f"Checked NixOS boot entries: {checked}."


def collect(nix, esp, token=None):
    fd = os.open(LOCK, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        keep, remove, _, current_token = plan()
        if token is not None and token != current_token:
            return False, "The system generations changed. Reopen the menu to review the new cleanup plan.", []
        env = dict(os.environ, LC_ALL="C")
        if remove:
            deletion = subprocess.run(
                [f"{nix}/bin/nix-env", "-p", str(PROFILE), "--delete-generations", *map(str, remove)],
                env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            if deletion.returncode:
                removed = [n for n in remove if not (PROFILE.parent / f"system-{n}-link").is_symlink()]
                return False, "Generation deletion was incomplete. Store cleanup was skipped.", [f"Deleted generations: {format_ids(removed)}"]

        before = shutil.disk_usage("/nix/store").free
        gc = subprocess.run([f"{nix}/bin/nix-store", "--gc"], env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        delta = shutil.disk_usage("/nix/store").free - before
        freed = re.search(r"(\d+) bytes freed", gc.stdout)
        if freed:
            space = f"Reclaimed {int(freed[1]) / 1024**2:.2f} MiB from the store"
        else:
            space = f"Free space changed by {delta / 1024**2:+.2f} MiB on the store filesystem"
        summary = f"Generations deleted: {len(remove)}. {space}."
        if gc.returncode:
            summary = "Store cleanup was incomplete. " + summary
        try:
            boot = boot_entries(esp)
        except OSError:
            boot = "Could not read the boot entries."
        details = [f"Retained generations: {format_ids(keep)}", f"Deleted generations: {format_ids(remove)}", boot]
        return gc.returncode == 0, summary, details


if __name__ == "__main__":
    import sys

    try:
        ok, summary, details = collect(sys.argv[1], Path(sys.argv[2]))
    except (OSError, ValueError, RuntimeError):
        sys.exit("Could not read system generations or complete cleanup.")
    print(summary, *details, sep="\n")
    sys.exit(0 if ok else 1)
