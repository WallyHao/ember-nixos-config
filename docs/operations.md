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

Install or update the declared user software profile as `wallyhao`, without
sudo:

```sh
cd ~/Workspace/ember-nixos-config
just profile install
```

The compatibility entry points remain:

```sh
just profile-install
./scripts/ember profile install
```

The profile is independent of the NixOS and Home Manager generations:

```sh
nix profile list
nix profile history --profile "$HOME/.local/state/nix/profiles/profile"
nix profile rollback --profile "$HOME/.local/state/nix/profiles/profile"
```

Edit `software/user-packages.nix`, then run `just profile install` to add or
remove declared applications. See [the software notes](../software/README.md).

The current configuration preserves a normal `passwd` change across reboots
and userborn restarts. This relies on the local PAM compatibility patch; keep
the account VM checks when updating inputs. See
[the password resolution](phase1-blocker-password.md).

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
paths remain until garbage collection. The weekly `ember-nix-gc` timer trims
the system profile to the newest five generations and then collects
unreachable store paths; booted/current roots are preserved.

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
just proxy status
just proxy on
just proxy off
just proxy check
just proxy import ~/Downloads/provider.yaml
```

The service is `ember-proxy.service`; its state remains under the intentional
legacy path `/var/lib/hearth-proxy`. `just proxy import` validates and stores
private provider data locally; it does not print subscription URLs. The proxy
starts only when provider/source data exists and the disabled marker is
absent. See [migration instructions](phase4-migration.md) for the private-data
copy step.

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
- Session menu: `ember-session` with Fuzzel confirmation for logout, reboot,
  and poweroff.

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
just desktop-config
just software-build
```

`just check` runs formatting, ShellCheck, repository scans, self-tests, flake
evaluation, and no-build checks. `just build` builds the system-preview
toplevel, not the real host.

The compatibility wrapper remains available:

```sh
scripts/ember info
scripts/ember check
scripts/ember build
scripts/hearth info
```

`scripts/ember` and `scripts/hearth` refuse `switch`, `test`, `boot`, `install`,
and `activate`. `system.autoUpgrade` and automatic rebuild are disabled. Normal
checks do not update either flake lock.

## Logs and cleanup

journald is persistent, capped at 128 MiB with 14-day retention. `fstrim` runs
weekly, not during boot. `ember-nix-gc` runs weekly and trims system generations
before collecting unreachable paths. `nix-store --optimise` remains a manual
maintenance operation; it is not run on every store write.

## Not supported yet

- Deployment/activation of the internal host; the source is buildable but the
  running host has not been switched.
- Disk swap or hibernation.
- Secure Boot or an encrypted root for the new system.
- Secrets deployment framework; private proxy data is handled by the bounded
  local migration/import tools.
- Real hardware performance, suspend, display, brightness, audio, and
  input-device validation. VM results do not replace those checks.
