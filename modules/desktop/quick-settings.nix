{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  colors = config.ember.appearance.colors;
  focusRing = config.wayland.windowManager.niri.settings.layout.focus-ring;
  proxyPanel = osConfig.environment.etc."ember/proxy-panel".source or null;
  settings = (pkgs.formats.toml { }).generate "wifi-manager.toml" {
    compact = true;
    position = "center";
    show_on_start = false;
  };
  stylesheet = pkgs.writeText "wifi-manager-colors.css" ''
    .wifi-panel {
      background-color: alpha(${colors.base00}, 0.95);
      border-color: ${focusRing.active-color};
      border-width: ${toString focusRing.width}px;
    }

    .header-title {
      font-size: 21px;
    }

    .cc-detail-title, .cc-tile-title, .ssid-label, .device-name, .cc-battery-summary {
      font-size: 17px;
    }

    .header-title, .cc-detail-title, .cc-tile-title, .ssid-label,
    .device-name, .cc-section-heading, .cc-current-device, .cc-volume-label, .cc-battery-summary {
      color: ${colors.base05};
    }

    .cc-tile-status, .cc-detail-status, .network-subtitle, .device-subtitle,
    .cc-section-heading, .cc-current-device, .cc-volume-label, .subtab-button,
    .password-entry, .password-title, .connect-button, .cancel-button,
    .cc-battery-details, .cc-proxy-actions button, .cc-proxy-actions label,
    .cc-proxy-actions entry {
      font-size: 14px;
    }

    .cc-tile-status, .cc-detail-status, .network-subtitle, .device-subtitle, .cc-battery-details {
      color: ${colors.base04};
    }

    button.cc-tile, .cc-current-device-row, .cc-battery-row {
      background-color: ${colors.base01};
    }

    button.cc-tile:hover, button.cc-tile:active, button.cc-tile.cc-tile-active,
    button.cc-tile.cc-tile-active:hover, .network-row:hover, .network-row.connected,
    .device-row:hover, .device-row.connected, .cc-device-list row:selected,
    .subtab-button:checked {
      background-color: ${colors.base02};
    }

    .cc-tile-icon, .cc-audio-device-icon, .cc-default-device, .cc-battery-icon,
    .subtab-button:checked {
      color: ${colors.base0A};
    }

    switch:checked, scale highlight, .connect-button {
      background-color: ${colors.base0A};
    }

    .connect-button {
      color: ${colors.base00};
    }

    .connect-button:hover {
      background-color: ${colors.base09};
    }

    .cc-proxy-actions button, .cc-proxy-actions entry {
      background: ${colors.base01};
      color: ${colors.base05};
      border: 1px solid ${colors.base02};
      border-radius: 8px;
      padding: 6px 10px;
      box-shadow: none;
    }

    .cc-proxy-actions label {
      color: ${colors.base05};
    }

    .cc-proxy-actions button:hover, .cc-proxy-actions row:selected {
      background-color: ${colors.base02};
    }

    .cc-proxy-actions button:disabled, .cc-proxy-actions button:disabled label {
      color: ${colors.base04};
    }

    .cc-proxy-actions popover > contents {
      background: ${colors.base01};
    }

    .wifi-panel button:focus-visible, .wifi-panel switch:focus-visible,
    .wifi-panel scale:focus-visible, .password-entry:focus {
      outline-color: ${colors.base0A};
    }
  '';
  wifiManager = pkgs.callPackage ../../packages/wifi-manager.nix { };
  busName = "com.github.wifi_manager.Daemon";
  busPath = "/com/github/wifi_manager/Daemon";
  toggle = pkgs.writeShellApplication {
    name = "ember-quick-settings";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      systemctl --user start ember-quick-settings.service
      exec busctl --user --timeout=5s call ${busName} ${busPath} ${busName} Toggle
    '';
  };
in
{
  config = lib.mkIf config.ember.desktop.enable {
    ember.desktop.actions.controlCenter = [ (lib.getExe toggle) ];

    xdg.configFile = {
      "wifi-manager/config.toml".source = settings;
      "wifi-manager/style.css".source = stylesheet;
    };

    systemd.user.services.ember-quick-settings = {
      Unit = {
        Description = "Ember quick settings panel";
        Requisite = [ "niri.service" ];
        # Preload the hidden panel once the compositor/session is ready.
        # Do not put D-Bus/GTK initialization on the session's critical path.
        After = [
          "niri.service"
          "graphical-session.target"
        ];
        PartOf = [ "niri.service" ];
        X-Restart-Triggers = [
          settings
          stylesheet
        ];
      };
      Service = {
        Type = "dbus";
        BusName = busName;
        ExecStart = lib.getExe wifiManager;
        Environment = lib.optional (proxyPanel != null) "EMBER_PROXY_PANEL=${proxyPanel}";
        TimeoutStartSec = 10;
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
