{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ember.gaming;
in
{
  options.ember.gaming.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the Steam/Proton gaming runtime for the Ember desktop.";
  };

  config = lib.mkIf cfg.enable {
    # Steam is a system component rather than a profile application: it needs
    # the 32-bit graphics stack, pressure-vessel helpers, controller udev rules
    # and a setuid-free runtime that only the NixOS module wires up.
    programs.steam = {
      enable = true;

      # Launch options are resolved inside Steam's FHS runtime. Put the
      # wrappers there instead of relying on the host PATH being inherited.
      extraPackages = [
        pkgs.gamemode
        pkgs.mangohud
      ];

      # GE-Proton adds media codecs and newer Wine fixes. It is registered
      # through STEAM_EXTRA_COMPAT_TOOLS_PATHS and selected per game in
      # Steam's Compatibility settings; no runtime files are copied into
      # the Steam directory.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    # Steam and many games are X11 clients. Niri 25.08+ spawns
    # xwayland-satellite on demand when it is in PATH; this is what gives
    # Steam a DISPLAY and turns its window into a normal Niri window.
    environment.systemPackages = [
      pkgs.xwayland-satellite
      pkgs.mangohud
    ];

    # GameMode raises the game process priority while it runs.
    programs.gamemode.enable = true;

    # Nested gamescope for fullscreen games: stable swapchain, cursor grab,
    # resolution scaling and FSR. The environment defaults put gamescope and
    # therefore the game on the RTX 4060, while Niri itself stays on the Intel
    # iGPU. Every value remains overridable at runtime.
    programs.gamescope = {
      enable = true;
      capSysNice = true;
      env = {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };
    };

    # `nvidia-offload steam` covers a whole session; per-game launch options
    # use the same four variables directly (see docs/gaming.md). PRIME offload
    # itself stays enabled in hosts/ember/hardware.nix.
    hardware.nvidia.prime.offload.enableOffloadCmd = true;

    assertions = [
      {
        assertion = config.hardware.nvidia.prime.offload.enable;
        message = "ember.gaming expects PRIME render offload; the RTX 4060 is not the display GPU.";
      }
      {
        assertion = config.ember.desktop.enable;
        message = "ember.gaming requires the Ember graphical desktop.";
      }
    ];
  };
}
