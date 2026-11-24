# Machine-specific facts and overrides for the Lenovo Legion Y7000 IRX9
# (83JJ). The shared hosts/hardware/portable.nix closure owns firmware,
# microcode, i915/amdgpu, the 32-bit graphics stack, video drivers and the
# NVIDIA open module.
{ config, lib, ... }:
{
  # Activate nixos-facter once a report exists. Generate it on the host with:
  #   sudo nixos-facter --hardware cpu,memory,pci,bios -o hosts/ember/facter.json
  # The restricted probe set keeps serial numbers, MAC addresses and block
  # device paths out of the repository.
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  # nvidia-drm's fbdev helper keeps the dGPU from entering runtime suspend and
  # is redundant here: the internal panel and console are driven by i915.
  boot.kernelParams = [
    "nvidia_drm.fbdev=0"
    # Permit deeper NVMe APST power states (55 ms max exit latency).
    "nvme_core.default_ps_max_latency_us=55000"
    # Let the HDA controllers runtime-suspend instead of unbinding the dGPU
    # audio function at resume (see the comment below). Kernel parameters are
    # used rather than modprobe.d because snd_hda_intel is also loadable from
    # the initrd, where /etc/modprobe.d does not apply yet.
    "snd_hda_intel.power_save=1"
    "snd_hda_intel.power_save_controller=Y"
  ];

  # AX203 does not participate in mounting the local NVMe. Load both Intel
  # Wi-Fi components after the full firmware tree is available. The initrd
  # firmware picker sees only the module's advertised API 100, while this
  # card actually needs the bundled fallback API 89 firmware.
  boot.kernelModules = [
    "iwlwifi"
    "iwlmvm"
  ];

  # Intel iGPU is the default display path; NVIDIA is available through
  # PRIME render offload. Fixed bus IDs are acceptable only in this
  # single-machine overlay; the shared closure never wires PRIME.
  hardware.nvidia = {
    prime = {
      offload.enable = true;
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
    powerManagement.finegrained = true;
    # The open 595+ driver uses the kernel suspend notifier by default.
    # Do not enable the older systemd suspend services as well.
  };

  ember.hardware = {
    # Keep the dGPU out of Niri's DRM enumeration so NVIDIA runtime D3 can
    # suspend it while idle. This path is host state, not shared policy.
    ignoreDrmDevice = "/dev/dri/by-path/pci-0000:01:00.0-render";
    kvmModule = "kvm-intel";
  };

  # Do NOT unbind 0000:01:00.1 at resume. snd_card_free() waits for every open
  # file descriptor on the card, so an audio stream still held by PipeWire
  # turns the unbind into an unkillable D-state task. 2026-11-23 11:39 log:
  #   task:sleep-actions-p state:D  snd_card_free+0x7a [snd]
  #   task:tlp blocked on a mutex likely owned by sleep-actions-p (control_store)
  #   Freezing user space processes failed (2 tasks refusing to freeze)
  #   poweroff requested 11:46:22 -> never executed, hard power-off at 11:47:35
  # The HDA controllers now runtime-suspend (snd_hda_intel.power_save=1 above),
  # which drops the same runtime PM reference without tearing the card down.

  assertions = [
    {
      assertion = !config.hardware.nvidia.prime.sync.enable;
      message = "Ember's laptop uses PRIME offload, not PRIME sync.";
    }
    {
      assertion = !config.hardware.nvidia.prime.reverseSync.enable;
      message = "Ember's laptop does not enable PRIME reverse sync.";
    }
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "uas"
    "sd_mod"
    "nvme"
    "btrfs"
    "crc32c"
    "r8169"
    "snd_hda_intel"
  ];
}
