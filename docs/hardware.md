# Hardware

Ember supports two physical machines. Hardware policy is split into a shared
driver closure (`hosts/hardware/portable.nix`) and a per-host overlay
(`hosts/<name>/hardware.nix`). The inventory selects both explicitly; Nix
evaluation never probes the running machine.

| Host | Machine | CPU | Graphics | Role |
| --- | --- | --- | --- | --- |
| `ember` | Lenovo Legion Y7000 IRX9 (83JJ) | Intel Core i7-13650HX | Intel iGPU + RTX 4060 Laptop | hybrid laptop |
| `forge` | MSI MAG B650M MORTAR WIFI | AMD Ryzen 7 9700X | AMD integrated graphics + RTX 3090 | desktop |

The shared closure enables both Intel and AMD microcode, `i915` and `amdgpu`
early KMS, the 32-bit graphics stack, and one NVIDIA open kernel module with
DRM modesetting. It deliberately contains no fixed PCI addresses, PRIME wiring,
DRM card numbers or render-device overrides. PCI matching selects the driver.

## Shared profile

`hosts/hardware/portable.nix` provides:

- Intel and AMD CPU microcode;
- `i915` and `amdgpu` in the initrd;
- `hardware.graphics` including 32-bit support;
- `nvidia`, `amdgpu` and `modesetting` video drivers;
- `hardware.nvidia.open`, `hardware.nvidia.modesetting` and `nvidiaSettings`;
- redistributable firmware.

Anything that depends on the physical machine stays in the host overlay:

- observed facts and `nixos-facter` report;
- PRIME offload bus IDs and fine-grained power management;
- a fixed DRM device path to ignore;
- Intel-only Wi-Fi modules;
- the CPU-specific KVM module;
- TLP platform profiles and battery settings.

## Ember observed hardware

These facts describe the laptop. The storage layout is declared separately in
`hosts/ember/storage-layout.nix`.

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

### Ember-specific policy

- PRIME render offload: Intel `PCI:0:2:0`, NVIDIA `PCI:1:0:0`; the iGPU drives
  the panel and the dGPU renders on request.
- Fine-grained NVIDIA runtime power management.
- `nvidia_drm.fbdev=0`, NVMe APST and HDA runtime-suspend parameters.
- Intel Wi-Fi components loaded after the full firmware tree.
- Niri ignores `/dev/dri/by-path/pci-0000:01:00.0-render` so the dGPU can
  runtime-suspend while idle.
- `kvm-intel` is loaded explicitly; TLP keeps the Lenovo platform profile and
  battery policy.

## Forge recorded hardware

The desktop is recorded from the Folio configuration. These values are
declaration data, not a fresh observation from this repository:

| Item | Recorded |
| --- | --- |
| Mainboard | MSI MAG B650M MORTAR WIFI |
| CPU | AMD Ryzen 7 9700X, 8 cores / 16 threads |
| Integrated graphics | AMD Radeon graphics (Ryzen 7000/9000 desktop iGPU) |
| Discrete GPU | NVIDIA RTX 3090 |
| Wi-Fi | RZ616 / MediaTek MT7922 class adapter |
| Ethernet | Realtek RTL8125 2.5GbE |
| Storage | External ZHITAI 1 TB USB SSD, bound in `hosts/forge/storage-spec.nix`; internal NVMe excluded |

### Forge-specific policy

- PRIME render offload: the monitor is connected to the motherboard DP output,
  so `amdgpu` drives the display and the RTX 3090 renders on request.
  `hosts/forge/hardware.nix` declares `amdgpuBusId = "PCI:16:0:0"` and
  `nvidiaBusId = "PCI:1:0:0"` (decimal bus IDs: `0000:10:00.0` and
  `0000:01:00.0`).
- No fine-grained NVIDIA power management; the host uses the offload wrapper
  and per-game environment instead.
- `kvm-amd` is loaded explicitly.
- TLP applies mains-only AMD P-State/EPP settings; no battery or ACPI platform
  profile keys are declared.

If the monitors are moved to the RTX 3090 outputs, remove the PRIME block and
set `ember.gaming.nvidiaOffload = false`. CUDA/compute workloads do not require
either change.

## Hardware report (nixos-facter)

Each host activates `nixos-facter` automatically once a report exists next to
its hardware overlay. Generate the report on the installed host, as root:

```sh
sudo nixos-facter --hardware cpu,memory,pci,bios -o hosts/ember/facter.json
sudo nixos-facter --hardware cpu,memory,pci,bios -o hosts/forge/facter.json
```

The restricted probe set deliberately omits serials, MAC addresses and block
device paths, so the report can stay in the repository without tripping the
static path scan.

Then re-run `just check` and rebuild the real target. Without the file the
integration is inert, so the hand-written hardware settings keep applying.
The report records hardware model and PCI identities, not serial numbers, MAC
addresses, block device paths or account data.

## Storage

The internal NVMe of the laptop (`0000:06:00.0`, 476.9 GiB) carries the layout
declared in `hosts/ember/storage-layout.nix`: a `hearth-esp` partition formatted
as `HEARTH_EFI` at `/boot`, and a `hearth-system` Btrfs partition labelled
`HEARTH_SYSTEM` providing the `@nix` and `@persist` subvolumes, while `/` stays
a tmpfs. Those labels and the by-id identifiers are intentional compatibility
state; do not rename or re-partition them.

The desktop uses a separate external ZHITAI 1 TB USB SSD
(`usb-ZHITAI_SPIRIT_PREMIUM_ZTE51T0AL262824228-0:0`). Its layout is declared in
`hosts/forge/storage-layout.nix`: an `ember-esp` partition formatted as
`EMBER_EFI` at `/boot`, and an `ember-system` Btrfs partition labelled
`EMBER_SYSTEM` providing the `@nix` and `@persist` subvolumes, while `/` stays a
tmpfs. The internal 2 TB NVMe holds unrelated Windows/data partitions and is
deliberately not referenced. The USB by-id path includes the drive serial, not
the port.

A conventional persistent root still requires a different layout module and
adjustments to `modules/system/persistence.nix`. Do not point
`hosts/forge/storage-spec.nix` at the laptop's NVMe identifiers.

No serial number, WWN, filesystem UUID or secret is recorded here, and device
names are not stable identities: layouts are bound by declaration and label,
never by `/dev/sdX`.

## Evidence limits

The observed `runtime_status`, platform profile, and `power_now` are transient.
They do not prove the new configuration will enter the same GPU runtime-suspend
state or achieve any measured power result. GPU power, suspend/resume, boot
time, and idle memory remain to be measured on both installed systems.
