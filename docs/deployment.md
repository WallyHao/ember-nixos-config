# Deployment

How to move this repository onto the internal disk of the laptop. Nothing here
runs automatically, and none of it has been performed from this repository:
the host has not been activated and the private Folio data has not been copied.
Commands that install or activate need the operator's own decision and a fresh
check of the running host and the target mounts.

The system toplevel used below must come from a build of this repository that
you produced and verified, never from `system-preview`.

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

## 2. Repository directory on the target

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

## 3. Install the already-built system

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

Keep the previous system generation and then unmount:

```sh
cd ~
sudo umount -R /mnt
```

Booting from the internal disk is the operator's decision; nothing here reboots.
The installed system has hostname `ember`, login title `EMBERLIGHT`, user
`wallyhao`, and the existing password and `stateVersion`.

## 4. After the first boot

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
