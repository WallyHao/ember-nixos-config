"""Interactive entry point for `nixos refresh`."""
from datetime import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import NamedTemporaryFile

import garbage


MODES = {
    "Full maintenance     Run network and storage tasks in parallel": "full",
    "Network maintenance  Check connectivity, proxy, and Hong Kong nodes": "network",
    "Storage cleanup      Keep up to 5 generations and clean the Nix store": "storage",
    "Inspect only         Check network, boot entries, and the cleanup plan": "inspect",
}
LAST_MAINTENANCE = "Last maintenance:"


def choose(fzf, title, choices):
    env = {key: value for key, value in os.environ.items() if not key.startswith("FZF_DEFAULT_")}
    menu = subprocess.run(
        [fzf, "--no-input", "--layout=reverse", "--height=~12", "--info=hidden",
         "--no-multi", "--header", title],
        input="\n".join(choices) + "\n", text=True, stdout=subprocess.PIPE, env=env,
    )
    if menu.returncode in {1, 130}:
        return None
    if menu.returncode:
        raise OSError("maintenance menu failed")
    return menu.stdout.rstrip("\n")


def maintenance(backend, action, *args):
    command = [backend, action, *args]
    if os.geteuid() != 0:
        command = ["/run/wrappers/bin/sudo", "--", *command]
    result = subprocess.run(command, stdout=subprocess.PIPE, text=True)
    if result.returncode in {130, -2}:
        raise KeyboardInterrupt
    if result.returncode:
        return {}
    return json.loads(result.stdout)


def display(results):
    print("\nMaintenance results")
    for name, (ok, message, details, *_) in results.items():
        print(f"  {name} | {'OK' if ok else 'Failed'} | {message}")
        for line in details:
            print(f"    {line}")


def history_path():
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    return state / "ember-refresh" / "last-run"


def history():
    try:
        summary = history_path().read_text().strip()
    except (OSError, UnicodeError):
        return ""
    return summary if summary.startswith(LAST_MAINTENANCE) else ""


def save(results):
    path = history_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        with NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as temporary:
            try:
                summary = " | ".join(f"{name}: {result[1]}" for name, result in results.items())
                print(f"{LAST_MAINTENANCE} {datetime.now():%Y-%m-%d %H:%M} | {summary}", file=temporary)
                temporary.flush()
                os.replace(temporary.name, path)
            finally:
                Path(temporary.name).unlink(missing_ok=True)
    except OSError:
        print("Could not save the maintenance summary.", file=sys.stderr)


def main(fzf, backend, *args):
    if args or not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("Run nixos refresh in an interactive terminal without arguments.", file=sys.stderr)
        return 2
    previous = history()
    title = "Select a maintenance task | Enter to select | Esc to exit"
    choice = choose(fzf, f"{title}\n{previous}" if previous else title, MODES)
    if choice is None:
        return 130
    action = MODES[choice]
    worker_args = []
    if action in {"full", "storage", "inspect"}:
        try:
            snapshot = garbage.plan()
        except (OSError, ValueError, RuntimeError):
            print("Could not read system generations to build the cleanup plan.", file=sys.stderr)
            return 1
        token = garbage.preview(snapshot)
        if action != "inspect":
            confirm = choose(fzf, "Proceed with the cleanup plan above?", ["Cancel", "Run cleanup"])
            if confirm != "Run cleanup":
                return 130
            worker_args.append(token)

    print("Running maintenance...", flush=True)
    results = maintenance(backend, action, *worker_args)
    if not results:
        print("Could not run maintenance.", file=sys.stderr)
        return 1
    display(results)
    if action == "inspect":
        return 0 if all(result[0] for result in results.values()) else 1

    if results.get("Network", [False, "", [], False])[3]:
        choice = choose(fzf, "Enable the proxy and restore automatic node selection?", ["Keep current settings", "Restore automatic selection"])
        if choice == "Restore automatic selection":
            recovered = maintenance(backend, "restore")
            if not recovered:
                recovered = {"Network": [False, "Could not restore automatic proxy selection.", [], False]}
            display(recovered)
            results.update(recovered)

    save(results)
    return 0 if all(result[0] for result in results.values()) else 1


if __name__ == "__main__":
    try:
        sys.exit(main(*sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, ValueError, KeyError):
        print("Could not complete interactive maintenance.", file=sys.stderr)
        sys.exit(1)
