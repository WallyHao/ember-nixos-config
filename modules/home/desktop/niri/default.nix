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
            active-color = c.base0A;
            inactive-color = "#00000000";
            urgent-color = "#00000000";
          };
          border.off = { };
          background-color = c.base00;
        };

        prefer-no-csd = { };
        screenshot-path = "~/Pictures/Screenshots/Screenshot_%Y-%m-%d_%H-%M-%S.png";

        # Square windows for every window rule; no exception restores radius.
        window-rule._children = [
          {
            geometry-corner-radius = 0;
            clip-to-geometry = true;
          }
        ];

        overview.backdrop-color = c.base00;
        hotkey-overlay.skip-at-startup = { };

        binds = import ./binds.nix {
          inherit modifier;
          actions = config.ember.desktop.actions;
        };
      };
    };
  };
}
