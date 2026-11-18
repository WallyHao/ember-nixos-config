# Hardware

Observed hardware facts for the laptop. They describe the machine; the storage
layout is declared separately in `hosts/ember/storage-layout.nix`.

| Item | Observed |
| --- | --- |
| DMI vendor / product | LENOVO / 83JJ |
| Product | Legion Y7000 IRX9 |
| BIOS | PTCN07WW, 2024-04-29 |
| CPU | 13th Gen Intel Core i7-13650HX, 14 cores / 20 threads |
| Memory | MemTotal 24,320,992 KiB |
| UEFI | `/sys/firmware/efi` present |
| CPU driver | `intel_pstate`, EPP includes balance_performance/balance_power |
| Platform profile | low-power, balanced, balanced-performance, performance, custom |
| Intel iGPU | `0000:00:02.0`, `8086:a78b`, i915, boot_vga=1 |
| NVIDIA GPU | `0000:01:00.0`, `10de:28e0`, RTX 4060 Laptop, nvidia |
| NVIDIA audio | `0000:01:00.1`, `10de:22be`, snd_hda_intel |
| Wi-Fi | `0000:00:14.3`, `8086:7a70`, iwlwifi |
| Ethernet | `0000:0c:00.0`, `10ec:8168`, r8169 |
| NVMe | `0000:06:00.0`, `1cc4:6b13`, nvme |
| Audio | `0000:00:1f.3`, `8086:7a50`, snd_hda_intel |
| Sleep | `s2idle [deep]` selected at observation time |

The old system's NVIDIA version was 595.112.07. The new configuration does not
pin that version and uses the locked nixpkgs default branch with the open
kernel module.

## PRIME bus IDs

NixOS `hardware.nvidia.prime` uses decimal PCI values. For the observed
addresses the decimal and hexadecimal digits coincide:

- Intel: `PCI:0:2:0`
- NVIDIA: `PCI:1:0:0`

These values are written only in `hosts/ember/hardware.nix`.

## Storage

The internal NVMe (`0000:06:00.0`, 476.9 GiB) carries the layout declared in
`hosts/ember/storage-layout.nix`: a `hearth-esp` partition formatted as
`HEARTH_EFI` at `/boot`, and a `hearth-system` Btrfs partition labelled
`HEARTH_SYSTEM` providing the `@nix` and `@persist` subvolumes, while `/` stays
a tmpfs. Those labels and the by-id identifiers are intentional compatibility
state; do not rename or re-partition them.

No serial number, WWN, filesystem UUID or secret is recorded here, and device
names are not stable identities: the layout is bound by declaration and label,
never by `/dev/sdX`.

## Hardware report (nixos-facter)

`hosts/ember/hardware.nix` activates `nixos-facter` automatically once a report
exists next to it. Generate the report on the installed host, as root:

```sh
sudo nixos-facter --hardware cpu,memory,pci,bios -o hosts/ember/facter.json
```

The restricted probe set deliberately omits serials, MAC addresses and block
device paths, so the report can stay in the repository without tripping the
static path scan.

Then re-run `just check` and rebuild the real target. Without the file the
integration is inert, so the hand-written hardware settings keep applying.
The report records hardware model and PCI identities, not serial numbers, MAC
addresses, block device paths or account data.

## Evidence limits

The observed `runtime_status`, platform profile, and `power_now` are transient.
They do not prove the new configuration will enter the same GPU runtime-suspend
state or achieve any measured power result. GPU power, suspend/resume, boot
time, and idle memory remain to be measured on the eventual installed system.
