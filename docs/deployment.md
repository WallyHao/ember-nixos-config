# Deployment

How to move this repository onto the target disk of a supported machine.
Nothing here runs automatically: the laptop has not been activated, the desktop
external USB SSD is recorded but not installed, and the private Folio data has
not been copied. Commands that install or activate need the operator's own
decision and a fresh check of the running host and the target mounts.

The system toplevel used below must come from a build of this repository that
you produced and verified, never from `system-preview` or
`system-preview-forge`.

## Supported hosts

| Host | State |
| --- | --- |
| `ember` | Laptop disk bound and confirmed; deployment gated on the operator actually running it. |
| `forge` | Desktop external 1 TB USB SSD bound and confirmed; internal NVMe is excluded. Not installed yet. |

Adding another machine means adding an inventory host, a hardware overlay and a
storage declaration. Do not reuse `ember` storage identifiers, PRIME bus IDs or
the fixed Niri DRM path.

## 1. Mount the target and copy private data

Run from the host that currently holds the internal disk, with the disk mounted
below `/mnt`:

```sh
./scripts/ember migrate-folio-data
```

The tool verifies that the mounted filesystems are the original
`HEARTH_SYSTEM` and `HEARTH_EFI` labels, requests local sudo, then:

- extracts only `proxies` entries and HTTP subscription sources/authentication
  from the Folio Mihomo data into `/mnt/persist/var/lib/hearth-proxy/sources.yaml`
  (mode 0700/0600, existing sources and same-UUID network profiles backed up
  first, disabled marker preserved);
- copies saved NetworkManager keyfiles from
  `/etc/NetworkManager/system-connections` by UUID into the matching persistent
  directory as `root:root`, mode 0600.

It does not copy Folio rules, DNS, listeners, commands, `machine-id`, keyring,
accounts or its network management framework, and it changes no Folio service.
It prints counts and status only, never nodes, URLs, SSIDs or passwords.

A non-zero `connections_needing_agent_secret` count means some keyfiles carry no
reusable password; those connections must be completed in the local session
afterwards. Copying a keyfile is not proof that every connection authenticates.
The copy touches several target files and is not atomic: inspect the private
backups and the target state before retrying a failure.

If the private sources are not readable without a password in your session, run
the step interactively as the owner of those files. Never paste private sources
into chat, the repository, or the Nix store.

## 2. Local initial account hash

The repository contains no usable account hash. Before building the installable
system, create the git-ignored local file with the existing password, or with a
new one that you change after the first login:

```sh
printf '"%s"\n' "$(mkpasswd -m sha-512)" > users/wallyhao/bootstrap-password.local.nix
chmod 600 users/wallyhao/bootstrap-password.local.nix
```

Without this file the build still evaluates with an unusable placeholder hash,
and the account cannot log in.

## 3. Repository directory on the target

The canonical directory is `ember-nixos-config`; `hearth-nixos-config` remains a
compatibility link so existing profile entries keep resolving their
`originalUrl`. Inspect before changing anything:

```sh
ls -ld /mnt/persist/home/wallyhao/Workspace/*nixos-config
```

- Old directory is real, new name absent: keep a copy of the old tree, move the
  directory to `ember-nixos-config`, and create the relative
  `hearth-nixos-config` symlink to it.
- New directory already exists next to the old symlink: skip the rename.
- Both names are real directories: compare and preserve the changes in each.
  Never overwrite or `rm -rf` either tree.

Then copy this repository over the canonical directory. Other personal data in
the target home is left alone.

## 4. Install the already-built system

Keep the repository root free of build products (`result*`, `*.qcow2`); put GC
roots outside it, for example:

```sh
nix build --no-link --no-update-lock-file \
  path:.#nixosConfigurations.ember.config.system.build.toplevel \
  --out-link /tmp/ember-system
```

Install only when the target is mounted, so a missing mount cannot write into
the host's plain `/mnt`:

```sh
mountpoint -q /mnt && mountpoint -q /mnt/boot && mountpoint -q /mnt/nix && mountpoint -q /mnt/persist &&
  sudo nixos-install --root /mnt --system "$(readlink -f /tmp/ember-system)" --no-root-passwd --no-channel-copy
mapfile -t software_paths < <(./scripts/ember software-build)
sudo nix copy --no-check-sigs --to 'local?root=/mnt' "${software_paths[@]}"
```

`--no-check-sigs` is only for copying closures built locally; it does not change
the global trust configuration. `software-build` prints the store paths the
offline profile install needs, so copying `software/bootstrap/packages` text
alone is not enough.

This example installs `ember`. For `forge`, use
`path:.#nixosConfigurations.forge` and confirm its storage binding first.

Keep the previous system generation and then unmount:

```sh
cd ~
sudo umount -R /mnt
```

Booting from the internal disk is the operator's decision; nothing here reboots.
The installed system has hostname `ember`, login title `EMBERLIGHT`, user
`wallyhao`, and the existing password and `stateVersion`.

## Activating on an already-installed host

`nixos apply` is the routine path only when the machine already boots the
declared layout (tmpfs root, `/nix` and `/persist` on the declared disk). On
`ember` the repository checkout is `/home/wallyhao/Workspace/ember-nixos-config`,
which is what `programs.nixos-cli.settings.config_location` points at.

Review the whole worktree first: `nixos apply` evaluates `path:` and therefore
includes every tracked and untracked change, not only the last edit. Build
without activating, then activate explicitly:

```sh
nix build --no-link --no-update-lock-file \
  path:.#nixosConfigurations.ember.config.system.build.toplevel
sudo nixos apply --no-update-lock-file
```

Keep the previous generation for rollback. A generation that only changes the
initrd or kernel still needs a reboot before that part is exercised. `forge` is
bound to its external USB SSD, but it is not installed yet; perform the install
from an installer environment first, then use `nixos apply` on later updates.

## 5. After the first boot

```sh
cd ~/Workspace/ember-nixos-config
just apps              # install the declared software profile
just vpn               # proxy status; import a provider file when needed
```

Open a new Foot window after the profile install so `omp` and the other profile
binaries are on `PATH`. Then verify the parts that virtual checks cannot cover:
Wi-Fi and saved connections, proxy nodes and latency, input method, audio,
brightness, lock/unlock, suspend/resume, and appearance on the real panel.

To revert, select the retained previous generation in the boot menu. Do not
format or clear private state to recover: the persistent data and the previous
generation are the rollback path.
