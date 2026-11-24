# Operations

## First login

The default entry is greetd/tuigreet; log in as `wallyhao` with the initial
password defined by the account setup. Change it at the first opportunity:

```sh
passwd
```

The graphical session starts `niri-session`; Waybar, Mako, and the other user
services start with the session. tty2 is kept as a password-protected rescue
VT. There is no autologin. Noctalia is retired and is not launched.

Quick settings starts hidden with the graphical session, so `Super+C` toggles
the resident panel. The service restarts after a crash; the shortcut can also
start it if it has stopped. Login audio muting runs after the graphical session
target, so its bounded wait for an audio output does not delay Waybar or portals.

Install or update the declared user software profile as `wallyhao`, without
sudo:

```sh
cd ~/Workspace/ember-nixos-config
just apps
```

The menu defaults to `install`; `list`, `history`, `rollback`, and `build` are
in the same menu. `./scripts/ember profile install` is the non-interactive
equivalent used by tests.

The profile is independent of the NixOS and Home Manager generations:

```sh
nix profile list
nix profile history --profile "$HOME/.local/state/nix/profiles/profile"
nix profile rollback --profile "$HOME/.local/state/nix/profiles/profile"
```

Edit `software/selection/user-packages.nix`, then run `just apps` to add or
remove declared applications. See [the software notes](../software/README.md).

The current configuration preserves a normal `passwd` change across reboots
and userborn restarts. This relies on the local PAM compatibility patch; keep
the account VM checks when updating inputs.

`sudo` requires the account password. Root password login is locked; do not
set the same bootstrap password for root.

## Boot menu

systemd-boot is configured with `timeout = 0`, so the newest generation boots
without a countdown. The menu is not removed:

- Hold **Space** during boot to enter the menu.
- To request the menu for the next boot only:

```sh
bootctl set-timeout-oneshot 5
```

- Or schedule a one-shot menu reboot:

```sh
systemctl reboot --boot-loader-menu=5
```

`configurationLimit = 5` limits boot entries to the five most recent retained
generations. A new installation with fewer generations shows the actual
entries. This limit is not the garbage-collection retention count.

## Recovery

Select an older generation in the printed systemd-boot menu. Historical store
paths remain until garbage collection. The `ember-nix-gc` timer, which runs
after boot and every three days, keeps up to five system generations. It
prioritizes the selected profile generation and entries for the booted and active
closures, then fills the remaining slots with the newest generations. Afterwards
it collects unreachable Store paths.

To force a one-off boot without activating the host:

```sh
/run/current-system/bin/switch-to-configuration boot
```

is an activation-time command, not part of the normal migration workflow.

## Network and proxy

NetworkManager owns connections. DNS uses systemd-resolved. The Wi-Fi backend
is `wpa_supplicant`, powersave is disabled, and the firewall allows no inbound
TCP/UDP ports by default.

The managed Mihomo proxy is controlled through the repository:

```sh
just vpn
```

The menu offers `status` (default), `on`, `off`, `check`, `import`, `nodes`, and
`select`; `import` prompts for the private provider YAML path, which may contain
spaces, and `select` prompts for a node name, `AUTO`, or `DIRECT`. `select` pins
that member of the `SELECT` group, which defaults to `AUTO`; the choice
survives restarts. The same commands are available as
`ember-proxy nodes` and `ember-proxy select NAME`. The
service is `ember-proxy.service`; its state remains under the intentional
legacy path `/var/lib/hearth-proxy`. `import` validates and stores
private provider data locally; it does not print subscription URLs. The proxy
starts when provider/source data exists, the disabled marker is absent, and
a direct Internet probe returns HTTP 204. NetworkManager connects using
saved profiles as usual. Either Wi-Fi or wired access can satisfy the probe.
If startup is deferred, the timer retries every 30 seconds in the background.
On a captive network, complete the portal sign-in and allow the next retry.
`ember-proxy off` disables automatic startup across reboots. `ember-proxy on`
clears that override and attempts startup immediately.

`AUTO` prefers `HK-AUTO`, then the general `NODES` group, with `DIRECT`
as a fallback when its health check succeeds. Mihomo measures HTTPS latency
on startup and every minute, including nodes from HTTP subscriptions. The
Hong Kong group uses the lowest measured latency among available nodes whose
names match `ember.proxy.hongKongNodeFilter` (e.g. 香港, 🇭🇰, HK, Hong Kong).
Run `ember-proxy select AUTO` to resume automatic selection after pinning a
node. See [deployment](deployment.md) for the private-data copy step.

## Phone ↔ computer files

`file-drop` is a resident miniserve instance started with `multi-user.target`.
It serves `~/Downloads/Share` over HTTP with basic authentication, so the phone
needs no app: open `http://<ember LAN address>:7373/` in a browser and upload,
download, or reload the list.

The credential is generated on the first start and never enters the Nix store
or the unit's command line:

```sh
cat ~/.local/state/file-drop/auth      # wallyhao:<password>
```

Each browser asks once and remembers it afterwards. The file lives in a
preserved directory, so the password survives reboots. Resetting it means
deleting the file and restarting the unit, which generates a fresh one:

```sh
rm ~/.local/state/file-drop/auth
sudo systemctl restart file-drop
cat ~/.local/state/file-drop/auth
```

To choose the password instead, write the file yourself and restart the same
way. The unit reads it once at start and only regenerates a missing or empty
file:

```sh
umask 077
printf 'wallyhao:<new-password>\n' > ~/.local/state/file-drop/auth
sudo systemctl restart file-drop
```

Three properties of that format, verified against miniserve 0.35.0: the
password must not contain `:` (the parser splits on it and rejects the
remainder as a malformed hash), every line adds another accepted credential
rather than replacing the old one, and a file that is not `0600` stays readable
by anything in the account. After a change, a browser still holding the old
credential has to drop its saved login for that address before it prompts again.

miniserve logs the address it bound at startup, including the LAN one to open on
the phone:

```sh
journalctl -u file-drop -b | grep 'http://'
```

`-q/--qrcode` would only render a QR code inside that same page, so it is not
enabled.

Uploads keep their original names and never overwrite: a duplicate name is
rejected with a conflict and the existing file stays. The web page has no
delete button, so deleting or renaming happens on the computer, inside
`~/Downloads/Share`.

Only TCP 7373 is opened; every other port stays closed. The address comes from
DHCP, so reserve it on the router if a bookmark should survive a lease change.
If another process already holds 7373, the unit restarts in a loop and the
journal reports the bind failure; it never falls back to another port.

## Graphical session

- Greeter: greetd + tuigreet on tty1; no automatic session.
- Niri: managed KDL at `~/.config/niri/config.kdl`.
- Bar: Waybar, 36 px top bar, with the Emberlight palette.
- Launcher: Fuzzel.
- Notifications: Mako.
- Terminal: Foot, using the managed Emberlight palette.
- Input method: Fcitx5/Rime; the session environment is configured by the
  system and Home Manager modules.
- Audio: PipeWire/WirePlumber with rtkit; PulseAudio daemon is disabled.
- Keyring: GNOME Keyring is the only Secret Service; greetd PAM unlocks the
  Login keyring with the login password.
- Portals: GTK file chooser and GNOME sharing/Secret backend; Nautilus is not
  installed by the Niri module.
- Lock/idle: swaylock/swayidle and the `ember-lock` user service.
- Screenshots: `Print` captures a region with grim/slurp and opens it in Satty
  for annotation, using the Emberlight palette and desktop font. If Satty is
  not installed, the region is saved to `~/Pictures/Screenshots` instead.
  Satty's GTK chrome follows Stylix's GTK target.
- Shell history: guarded Atuin integration in zsh, local only (no sync);
  Zellij is available as a terminal multiplexer with its built-in defaults.
- `Super+C` toggles the centered quick settings panel for Wi-Fi, Bluetooth,
  audio, brightness, battery, and the Ember proxy. The **Battery** tile
  shows charge, charging state, estimated time, and power draw when UPower
  supplies those values. The **Proxy** tile shows the service state and
  lets you enable or disable it. Choose **Load nodes** to open the searchable
  node selector, then **Apply** to select a node or restore `AUTO`. Polkit
  authorizes node access and changes.
  `Esc` closes the panel. `Super+P` opens the Fuzzel control menu for
  do-not-disturb and session actions.
- Bluetooth: enabled system-wide and on after every boot. The IdeaPad EC keeps
  a persistent Bluetooth rfkill switch that starts blocked; a udev rule clears
  every Bluetooth switch when one appears, and `bluetoothd` clears it again
  before starting, so BlueZ `AutoEnable` powers `hci0` on. The Fn wireless
  hotkey can still turn the radio off until the next boot.
- Session menu: `ember-session` with Fuzzel confirmation for logout, reboot,
  and poweroff.

## Virtual machines

libvirt manages QEMU/KVM guests and `virt-manager` is the desktop front end.
The account is in the `libvirtd` group, which Polkit uses to allow the system
connection (`qemu:///system`). Group membership is picked up by new login
sessions, so log out and back in after the first activation.

```sh
virsh -c qemu:///system list --all
virt-manager
```

Guest disks, NVRAM and saved state live under `/var/lib/libvirt`, which is
preserved on `/persist`; a reboot does not lose a VM. The files inside are
ordinary data: back up the images like any other file, and keep the repository
root free of `*.qcow2` files.

libvirt 12.8 enables `virt-secret-init-encryption.service`, which creates
`/var/lib/libvirt/secrets/secrets-encryption-key` with `systemd-creds`.
`systemd-creds` only uses its host key when `/var/lib/systemd` is on persistent
media. The tmpfs root therefore needs `/var/lib/systemd` preserved entire,
including `credential.secret`; keeping only its `timers` and `random-seed`
children makes activation fail with:

```text
systemd-creds[...]: TPM2 not available and host key located on temporary file system, no encryption key available.
```

If that failure appears during the first switch to a generation that adds
libvirt, bind the persistent directory before retrying once:

```sh
sudo mkdir -p /persist/var/lib/systemd
sudo mount --bind /persist/var/lib/systemd /var/lib/systemd
sudo systemctl restart virt-secret-init-encryption.service
```

Then rerun the activation. The reboot that follows uses the preservation mount
declared in `modules/system/persistence.nix`.

The default NAT network is defined but not started automatically until the
one-time autostart flag is set. Do this once so guests with networking start
without manual steps:

```sh
sudo virsh net-autostart default
sudo virsh net-start default
```

Remote graphical output uses the default SPICE/VNC settings. USB redirection
and TPM 2.0 emulation are not enabled; add `virtualisation.spiceUSBRedirection`
or `virtualisation.libvirtd.qemu.swtpm.enable` only when a guest needs them.

## Storage and removable drives

`udisks2` runs system-wide and `udiskie` runs in the user session. A mountable
filesystem that udisks2 reports, either at session start or when a drive is
plugged in, is mounted automatically under `/run/media/wallyhao/<label>`, and
its mountpoint is cleaned up when the device disappears; Mako shows the result.
There are no fstab entries for removable media, so nothing blocks boot when a
drive is absent. Use `udiskie-umount <path>` or
`udisksctl unmount -b /dev/disk/by-label/<label>` before unplugging.

Removable drives mount without an authentication prompt. An unconfigured
partition on a system-internal drive is subject to udisks2's Polkit policy and
may ask for the account password through the session Polkit agent. The mounted
NixOS subvolumes (`/nix`, `/persist`, `/boot`) are already mounted and are not
remounted by udiskie.

Automatic mounting is runtime only: it does not claim the data on a removable
drive is backed up or preserved across reinstalls. To mount a permanent
internal data disk at a fixed path before login, add a declarative
`fileSystems` entry with the filesystem UUID, `nofail`, and
`x-systemd.automount`; do not identify it by `/dev/sdX`.

## Gaming

The stack is enabled on both hosts (`ember.gaming.enable = true` in
`hosts/ember/default.nix` and `hosts/forge/default.nix`); rebuild before first
use. Steam, GE-Proton, GameMode, Gamescope, MangoHud, and `xwayland-satellite`
are system packages. The Steam library is preserved at
`/persist/home/wallyhao/.local/share/Steam`. On `ember`, launch
`nvidia-offload steam` for a whole session, or use the per-game offload
environment from the guide, to render on the RTX 4060. On `forge` the RTX 3090
is the display GPU and no offload wrapper is installed. Launch options,
Proton selection, VRR, and compatibility limits are in
[the gaming notes](gaming.md).

If the session fails, switch to tty2 and use the normal password login. Inspect
`systemctl status greetd`, `systemctl --user status niri.service`, the failed
user units, and the journal. Do not remove the keyring or add a second Polkit
agent to work around a failure.

Noctalia is not configured or started. Its old state directory is retained
only as rollback data; no migration service or IPC action reads it.

## Maintenance commands

```sh
just check
just build
just vm
just format
```

`just check` runs nixfmt, deadnix, actionlint, ShellCheck, the mock-backend CLI suite
(`tests/cli.sh`), repository scans, self-tests, flake evaluation, and no-build
checks. It instantiates the checks with one
`nix-eval-jobs` pass from the devShell, falling back to per-check `nix eval`
when the binary is unavailable, and fails on any evaluation error. `just build`
uses `nom` when it is on PATH and plain `nix build` otherwise; both print
exactly one store path. `just vm` builds all six VM checks, or one
selected from the menu. GitHub Actions runs the full VM suite on manual dispatch.
`just format` rewrites `.nix` files; `check` is the
read-only gate. The `storage-layout` and `desktop-config` checks have no
dedicated recipe; CI builds them directly:

```sh
nix build --no-link --no-update-lock-file \
  path:.#checks.x86_64-linux.storage-layout \
  path:.#checks.x86_64-linux.desktop-config
```

The non-interactive backend remains available:

```sh
scripts/ember info
scripts/ember check
scripts/ember build
scripts/ember software-build
scripts/ember proxy status
scripts/ember profile install
```

`scripts/ember` refuses `switch`, `test`, `boot`, `install`, and `activate`.
`system.autoUpgrade` and automatic rebuild are disabled. Normal checks do not
update either flake lock.

## NixOS tooling, direnv and editor support

`nixos-cli` is enabled with
`config_location = "path:/home/wallyhao/Workspace/ember-nixos-config"`, so it
works from any directory and includes untracked files. This lives in the
generated `/etc/nixos-cli/config.toml`, so it does not depend on shell
environment variables.

```sh
nixos features                 # build info, no system change
nixos generation list          # TUI generation browser
nixos option                   # search this system's options
nixos apply                    # activation; same effect as nixos-rebuild switch
```

`nixos apply` activates the system through `sudo`; nothing invokes it
automatically. `just check` and CI remain activation-free.

Run `nixos refresh` in an interactive terminal for full maintenance, network
maintenance, storage cleanup, or inspection. Full maintenance runs network
and storage work in parallel. Storage cleanup previews the exact generations
to delete and rechecks the plan after confirmation. The timer and the menu
use the same cleanup code and share a lock. The boot-menu audit reports missing
files. NixOS next refreshes boot entries during a normal system activation.

Network maintenance checks the Wi-Fi or Ethernet uplink and sends an HTTPS
probe through the local proxy, verifying the connection's route from Mihomo.
With `AUTO` selected it refreshes Hong Kong latency measurements. Manual
selections and the disabled marker are preserved unless you accept the
recovery prompt. The last maintenance summary is saved under
`~/.local/state/ember-refresh`; it records time, status and cleanup totals.

Exit codes are `0` for success, `1` for a failed task, `130` for cancellation
or interruption, and `2` when the command cannot open an interactive menu.

The repository root has an `.envrc` using the flake devShell. After the first
switch, authorize it once:

```sh
direnv allow .
```

`~/.local/share/direnv` is preserved at `/persist` (see
`users/wallyhao/persistence.nix`), so the approval survives reboot: the tmpfs
root would otherwise drop the allow database and block every `.envrc` again.
Editing an `.envrc` still requires a fresh `direnv allow`.

NixVim enables the `nixd` language server for Nix files; it comes from the
NixVim module, so no separate package is added to the user profile.

## Logs and cleanup

journald is persistent, capped at 128 MiB with 14-day retention. `fstrim` runs
weekly, not during boot. `ember-nix-gc` runs after boot and every three days,
then trims system generations before collecting unreachable paths.
`nix-store --optimise` remains a manual maintenance operation; it is not run on
every store write.

## Not supported yet

- Deployment/activation of the internal host; the source is buildable but the
  running host has not been switched.
- Disk swap or hibernation.
- Secure Boot or an encrypted root for the new system.
- Secrets deployment framework; private proxy data is handled by the bounded
  local migration/import tools.
- Real hardware performance, suspend, display, brightness, audio, and
  input-device validation. VM results do not replace those checks.
