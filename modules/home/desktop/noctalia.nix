{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.hearth.appearance.colors;
  palette = {
    dark = {
      mPrimary = c.base08;
      mOnPrimary = c.base00;
      mSecondary = c.base0D;
      mOnSecondary = c.base00;
      mTertiary = c.base0A;
      mOnTertiary = c.base00;
      mError = c.base08;
      mOnError = c.base00;
      mSurface = c.base00;
      mOnSurface = c.base05;
      mSurfaceVariant = c.base01;
      mOnSurfaceVariant = c.base04;
      mOutline = c.base02;
      mShadow = c.base00;
      mHover = c.base01;
      mOnHover = c.base05;
      terminal = {
        background = c.base00;
        foreground = c.base05;
        cursor = c.base05;
        cursorText = c.base00;
        selectionBg = c.base02;
        selectionFg = c.base05;
        normal = {
          black = c.base00;
          red = c.base08;
          green = c.base0B;
          yellow = c.base0A;
          blue = c.base0D;
          magenta = c.base0E;
          cyan = c.base0C;
          white = c.base05;
        };
        bright = {
          black = c.base03;
          red = c.base08;
          green = c.base0B;
          yellow = c.base0A;
          blue = c.base0D;
          magenta = c.base0E;
          cyan = c.base0C;
          white = c.base07;
        };
      };
    };
  };

  migrate = pkgs.writeShellScript "hearth-noctalia-state" ''
    exec ${pkgs.python3.withPackages (ps: [ ps.tomlkit ])}/bin/python3 ${./noctalia-state.py}
  '';
in
{
  config = lib.mkIf config.hearth.desktop.enable {
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
      checkConfig = true;
      customPalettes.hearth = palette;

      settings = {
        theme = {
          mode = "dark";
          source = "custom";
          custom_palette = "hearth";
        };

        shell = {
          font_family = "DejaVu Sans";
          offline_mode = true;
          external_ip_enabled = false;
          telemetry_enabled = false;
          setup_wizard_enabled = false;
          polkit_agent = true;
          clipboard_enabled = true;
          clipboard_keep_from_closed_apps = true;
          clipboard_history_max_entries = 100;
        };

        notification.enable_daemon = true;

        # Solid Hearth base00 behind the bar and panels. With no default image
        # path, the wallpaper layer renders only fill_color; transitions and
        # rotation stay off and nothing fetches a palette or image.
        wallpaper = {
          enabled = true;
          fill_color = c.base00;
          transition_on_startup = false;
          automation.enabled = false;
        };

        # No NIC test showed clone/fetch attempts caused by the default
        # plugin sources. offline_mode does not replace disabling them:
        # `enabled = false` prevents scanning and updating.
        plugins = {
          auto_update = "none";
          source = [
            {
              name = "official";
              kind = "git";
              location = "https://github.com/noctalia-dev/official-plugins";
              enabled = false;
            }
            {
              name = "community";
              kind = "git";
              location = "https://github.com/noctalia-dev/community-plugins";
              enabled = false;
            }
          ];
        };

        # 16px base glyph * 1.25 bar scale * 0.9 = 18px workspace dots.
        # Keep equal diameters and distinguish state by colour, without labels.
        widget = {
          workspaces = {
            style = "regular";
            show_labels = false;
            show_icons = false;
            pill_scale = 0.9;
            active_pill_size = 1.0;
            inactive_pill_size = 1.0;
            capsule_radius = 80.0;
            focused_color = c.base08;
            occupied_color = c.base0D;
            empty_color = c.base02;
            urgent_color = c.base0E;
            change_color_on_hover = false;
          };
          network = {
            color = c.base0D;
            show_label = false;
          };
          volume = {
            color = c.base0C;
            show_glyph = false;
            show_label = true;
          };
          battery = {
            color = c.base0B;
            display_mode = "none";
            show_label = true;
          };
          clock = {
            color = c.base06;
            format = "{:%m-%d  %H:%M}";
          };
        };

        bar = {
          order = [ "main" ];
          main = {
            position = "top";
            enabled = true;
            reserve_space = true;
            thickness = 42;
            # Explicitly override upstream floating-bar defaults. Only the
            # bar's own height is reserved; Niri supplies the 6px gap below.
            margin_ends = 0;
            margin_edge = 0;
            margin_opposite_edge = 0;
            radius = 0;
            shadow = false;
            background_opacity = 1.0;
            padding = 24;
            widget_spacing = 14;
            # Enlarge both glyphs and text. Font-only scaling would leave
            # Wi-Fi/tray symbols tiny; these yield roughly 22px body labels.
            scale = 1.25;
            font_scale = 1.25;
            font_weight = 600;
            start = [ "workspaces" ];
            center = [ ];
            end = [
              "tray"
              "network"
              "volume"
              "battery"
              "clock"
            ];
          };
        };
      };
    };

    # Runtime overrides are app-owned state; narrow migration runs before
    # Home Manager links the managed files so the declarative intent wins.
    home.activation.hearthNoctaliaAppearance =
      lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
        "${migrate}";
  };
}
