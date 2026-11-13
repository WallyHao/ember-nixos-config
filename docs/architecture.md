# Architecture

## Layering

```text
inventory/            identity, stateVersion, user, storage data
  └─ lib/eval-inventory.nix + inventory/schema.nix
       └─ lib/mk-host.nix
            ├─ modules/nixos/default.nix   capability modules
            ├─ hosts/laptop/               host policy and hardware
            ├─ users/wallyhao/persistence.nix
            └─ storage module (only when bound)

suites/nixos/base.nix      imports the capability modules
suites/nixos/laptop.nix    base + TTY-only laptop policy
hosts/laptop/default.nix   laptop suite + TLP parameters
```

`mk-host.nix` is the only assembly function. The real host, `system-preview`,
and VM boots all use it. They differ only at the edge: which hardware module
and which storage module are passed.

The preview and VM use explicit fixtures:

- `tests/fixtures/hardware.nix`: virtual hardware, no NVIDIA module, TLP
  service disabled only in the fixture.
- `tests/fixtures/storage.nix`: virtual `/dev/vda`, GPT, ESP, Btrfs `/persist`
  and `/nix`, tmpfs `/`.

No fixture value is copied into `hosts/laptop/storage-spec.nix`.

## Flake outputs

| Output | Phase-1 behavior |
| --- | --- |
| `nixosModules.default` | capability library + preservation module |
| `nixosModules.hearthLaptop` | host policy + hardware + identity + persistence; no storage |
| `lib.hearth.deployment` | serializable deployment state |
| `nixosConfigurations.hearth` | only when storage is bound and confirmed |
| `packages.x86_64-linux.system-preview` | real hardware + virtual storage fixture toplevel |
| `checks.x86_64-linux.system-preview` | same toplevel derivation |
| `checks.x86_64-linux.eval-contracts` | config rules and negative cases |
| `checks.x86_64-linux.vm-*` | accounts, persistence, offline boot |

## State model

The root is tmpfs. `/nix`, `/persist`, and the ESP are separate filesystems
supplied by a future storage layout module. `/persist` holds a mirrored tree:

```text
/persist/var/lib/nixos
/persist/var/lib/userborn
/persist/var/lib/bluetooth
/persist/var/lib/tlp
/persist/var/lib/systemd/{timers,random-seed}
/persist/var/log/journal
/persist/etc/NetworkManager/system-connections
/persist/etc/machine-id
/persist/home/wallyhao/{Workspace,Documents,Downloads,Pictures,.local/state/nix}
```

`preservation` bind-mounts these back. The preservation mount units run before
tmpfiles, so the persistent source directories are pre-created in initrd under
`/sysroot/persist`. `userborn` runs after `preservation.target`; its password
database lives in `/var/lib/nixos`.

## Deliberate omissions

No directory walker, scope DSL, configuration database, background manager,
auto-deployment service, desktop session, secrets provider, or package-profile
flake exists in phase 1.
