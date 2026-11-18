# Gaming

Status: opt-in, disabled on this host. `hosts/ember/default.nix` sets
`ember.gaming.enable = false`, so Steam, GE-Proton and the rest of the stack are
not in the current system closure. The stack is wired into the real system
assembly and the eval contracts; VM checks disable it because they have no real
GPU, and no frame rate, temperature or battery result has been measured.

To opt back in:

```nix
# hosts/ember/default.nix
ember.gaming.enable = true;
```

```sh
sudo nixos-rebuild switch --flake /persist/home/wallyhao/Workspace/ember-nixos-config#ember
```

That pulls the Steam/GE-Proton closure back into the system; the first rebuild
after the switch rebuilds it. Nothing below is active until then.

## Installed components

| Component | Role | Owner |
| --- | --- | --- |
| `programs.steam` | Steam client, 32-bit graphics stack, pressure-vessel helpers, controller udev rules | system (`modules/gaming.nix`) |
| `proton-ge-bin` (GE-Proton 11-12 from the pinned nixpkgs) | Compatibility tool with media codecs and newer Wine fixes | system, exposed to Steam through `STEAM_EXTRA_COMPAT_TOOLS_PATHS` |
| `xwayland-satellite` | X11 socket for Steam and X11 games under Niri | system |
| GameMode | Scheduling priority for the launched game | system |
| Gamescope | Nested fullscreen compositor, cursor grab, FSR upscaling | system |
| MangoHud | FPS/frame-time/GPU overlay | system |
| `nvidia-offload` | PRIME render offload wrapper for the RTX 4060 | system (NVIDIA module) |
| On-demand VRR | Variable refresh only while a game window is visible | Home Manager Niri config |

Steam is a system component, not a profile package: the `steam` wrapper needs
the 32-bit graphics stack, FHS runtime, setuid-free helpers, and udev rules
that `programs.steam` wires up. Do not add `steam` to
`software/selection/user-packages.nix`.

## Hybrid graphics

The Intel iGPU remains the display GPU. The RTX 4060 is a PRIME offload
device; a game that is not told to use it renders on the iGPU.

Two supported ways to put a game on the RTX 4060:

```sh
# Whole Steam session on the dGPU. Every game launched from this Steam
# inherits the variables. The Steam UI also keeps the dGPU awake.
nvidia-offload steam
```

or keep Steam on the iGPU and use Steam's per-game launch options. The
environment assignments do not depend on a host command being visible inside
Steam's runtime:

```text
__NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

The second form is the default recommendation for battery life: only the game
wakes the dGPU. `nvidia-offload` is provided by
`hardware.nvidia.prime.offload.enableOffloadCmd` in `modules/gaming.nix` for
terminal use, and GameMode/MangoHud are also installed into Steam's FHS runtime
through `programs.steam.extraPackages`.

Gamescope's system wrapper already exports the same four offload variables, so
a game launched through gamescope does not need an additional
`nvidia-offload`.

## Steam setup

1. Sign in and let Steam finish its first-run update.
2. **Settings → Compatibility → Enable Steam Play for all other titles**, then
   select the **GE-Proton** entry (currently GE-Proton 11-12).
3. For one title, use **Properties → Compatibility → Force the use of a
   specific Steam Play compatibility tool**.

Useful per-game launch options (`%command%` must stay last):

```text
gamemoderun mangohud %command%
```

```text
gamescope -f -w 1920 -h 1080 -W 1920 -H 1080 --force-grab-cursor --backend sdl -- %command%
```

Combined:

```text
gamescope -f -w 1920 -h 1080 -W 1920 -H 1080 --force-grab-cursor --backend sdl -- gamemoderun mangohud %command%
```

`--backend sdl` is the Niri-recommended backend because gamescope's Wayland
backend has cursor-lock problems. `-w/-h` is the game's internal resolution and
`-W/-H` the fullscreen output size; leaving them different enables FSR
(`Super+U` toggles it inside gamescope). Do not add `--hdr-enabled`: the Niri
session has no HDR output path.

If Steam shows a black window under Niri, launch it with `-system-composer`, or
disable **GPU accelerated rendering in web views** in Steam's Interface
settings. This is a known Steam/Niri interaction, not a driver failure.

## Performance notes

- **VRR** is configured as on-demand on `eDP-1`, and enabled only for windows
  whose app-id matches `^(gamescope|steam_app_.*)$`. The desktop stays at a
  fixed refresh rate. Verify support with `niri msg outputs`; if a game reports
  a different app-id, extend the rule in `modules/niri/default.nix`.
- **GameMode** runs as `gamemoded` and only adjusts process scheduling while a
  `gamemoderun`-wrapped game is active; it is not a permanent overclock or
  clock lock.
- **MangoHud** is diagnostic. Keep it off when measuring real performance,
  otherwise the overlay itself costs frames.
- **Power policy**: TLP owns the platform profile and keeps AC at `balanced`.
  For a short maximum-performance run on AC:
  `echo performance | sudo tee /sys/firmware/acpi/platform_profile`.
  TLP may reapply its policy on the next power-source event; this is not a
  permanent setting change.
- **No dGPU polling**: the configuration deliberately does not enable
  `nvidia-persistenced` or a `nvidia-smi` loop. The dGPU wakes for a game and
  runtime-suspends again after Steam and the game exit.
- **Shader caches** live under `steamapps/shadercache`. The first run of a game
  can stutter while DXVK/VKD3D compiles pipelines; that is not a configuration
  error.

## Compatibility limits

- Kernel-level anti-cheat (for example Vanguard or FACEIT) does not work under
  Proton. Check ProtonDB and Are We Anti-Cheat Yet before buying a title.
- GE-Proton covers most media-codec and Wine-fix gaps; if a game regresses,
  select the previous Proton version for that title only.
- Non-Steam launchers (Lutris, Heroic, Epic) are not installed by this
  configuration. Add them to the profile if needed; their Wine prefixes are
  separate from Steam's.
- External libraries on exfat/NTFS are supported, but games that rely on
  case-sensitive paths or symlinks are safer on btrfs/ext4.
- Steam Remote Play, dedicated servers, and local transfers stay firewalled
  off; opening them is an explicit `programs.steam.*.openFirewall` change.

## Storage

`/home/wallyhao` is a tmpfs. Only the declared persistent paths survive a
reboot. Steam's library, Proton prefixes, and shader caches are persisted at:

```text
/persist/home/wallyhao/.local/share/Steam
```

Games installed through Steam therefore consume `/persist` space:

```sh
df -h /persist
du -sh ~/.local/share/Steam/steamapps/*
```

Do not move the default library under a path that is not preserved. An external
library is fine while it stays mounted. Removing a game through Steam is the
correct way to reclaim space; Nix garbage collection does not manage game files.

## Verification

```sh
nix build path:.#checks.x86_64-linux.eval-contracts
nix build path:.#checks.x86_64-linux.desktop-config
nix build path:.#packages.x86_64-linux.system-preview
```

`desktop-config` validates the generated Niri KDL, including the on-demand VRR
output and window rules. `system-preview` proves the Steam closure evaluates and
builds; it does not install or activate the host.

On the installed system, check:

```sh
nvidia-smi                       # dGPU visible
niri msg outputs                 # panel mode and VRR capability
journalctl --user-unit niri -b   # "listening on X11 socket"
nvidia-smi                       # while a game runs: the game process on the dGPU
```

No FPS, temperature, suspend, or battery number is claimed here.
