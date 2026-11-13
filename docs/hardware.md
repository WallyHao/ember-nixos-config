# Hardware

Read-only observation from 2026-11-09, rechecked during implementation. These
are facts about the current machine, not a disk binding or a deployment
authorization.

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

These values are written only in `hosts/laptop/hardware.nix`.

## Storage observations

| Device | Observed | Planning meaning |
| --- | --- | --- |
| `sda` | USB, 953.9 GiB; `sda1` `/boot`, `sda2` current root/nix/home | current USB system, not a target |
| `nvme0n1` | NVMe, 476.9 GiB; p1 260 MiB, p2 204.7 GiB, p6 271.9 GiB | internal candidate; existing partitions, no authorization |
| `zram0` | 5.8 GiB current swap | old runtime state, not copied |

No serial number, WWN, filesystem UUID, or secret was collected. Device names
are not stable identities.

## Evidence limits

The observed `runtime_status`, platform profile, and `power_now` are transient.
They do not prove the new configuration will enter the same GPU runtime-suspend
state or achieve any measured power result. GPU power, suspend/resume, boot
time, and idle memory remain to be measured on the eventual installed system.
