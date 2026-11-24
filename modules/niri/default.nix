{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;
  modifier = config.ember.desktop.modifier;
in
{
  imports = [
    ./actions.nix
    ./single-window.nix
  ];

  config = lib.mkIf config.ember.desktop.enable {
    wayland.windowManager.niri = {
      enable = true;
      package = pkgs.niri;
      checkConfig = true;
      systemd.enable = true;
      xwaylandSatellitePackage = null;
      portalPackage = null;

      settings = {
        input = {
          keyboard.xkb.layout = "us";
          touchpad.natural-scroll = { };
        };

        cursor = {
          xcursor-theme = "Bibata-Modern-Ice";
          xcursor-size = 36;
        };

        layout = {
          gaps = 16;
          # Folio geometry, paired with the 36px Waybar exclusive zone.
          struts = {
            top = -12;
            bottom = 0;
            left = 0;
            right = 0;
          };
          center-focused-column = "never";
          default-column-width.proportion = 0.5;
          preset-column-widths._children = [
            { proportion = 0.5; }
            { proportion = 0.75; }
            { proportion = 1.0; }
          ];
          focus-ring = {
            on = { };
            width = 3;
            # base0A is the bright yellow accent; base08 keeps the same
            # palette but gives a dimmer, redder focus ring.
            active-color = c.base08;
            inactive-color = "#00000000";
            urgent-color = "#00000000";
          };
          border.off = { };
          background-color = c.base00;
        };

        # Camera motion only: the critical-damped defaults (damping 1.0,
        # stiffness 800/1000) stop dead, which reads as stiff. A little
        # underdamping makes the switch overshoot ~7% and settle back.
        # Window open/close keep niri's defaults.
        animations = {
          workspace-switch.spring._props = {
            damping-ratio = 0.65;
            stiffness = 600;
            epsilon = 0.0001;
          };
          horizontal-view-movement.spring._props = {
            damping-ratio = 0.65;
            stiffness = 700;
            epsilon = 0.0001;
          };
        };

        prefer-no-csd = { };

        window-rule._children = [
          {
            geometry-corner-radius = 10;
            clip-to-geometry = true;
          }
        ];

        overview.backdrop-color = c.base00;
        hotkey-overlay.skip-at-startup = { };

        # Keep the panel at its fixed refresh rate on the desktop. On-demand
        # VRR is enabled only while a game window is visible; the rules opt in
        # gamescope and Steam game windows. An output name that is not
        # connected is ignored.
        _children = [
          {
            output = {
              _args = [ "eDP-1" ];
              variable-refresh-rate._props = {
                on-demand = true;
              };
            };
          }
          {
            window-rule._children = [
              {
                match._props.app-id = "(?i)^(gamescope|steam_app_.*)$";
                variable-refresh-rate = true;
              }
            ];
          }
        ];

        binds = import ./binds.nix {
          inherit modifier;
          actions = config.ember.desktop.actions;
        };
      }
      // lib.optionalAttrs (config.ember.desktop.ignoreDrmDevice != null) {
        # Host policy: keep a laptop dGPU out of Niri's DRM enumeration so
        # NVIDIA runtime D3 can suspend it. A desktop whose discrete GPU drives
        # the display leaves this null.
        debug."ignore-drm-device" = config.ember.desktop.ignoreDrmDevice;
      };
    };
  };
}
