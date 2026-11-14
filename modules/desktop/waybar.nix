# Folio's actual bar layout; only palette roles and package identity differ.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;
  indicator = import ../../packages/input-language.nix { inherit pkgs; };
in
{
  config = lib.mkIf config.ember.desktop.enable {
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      settings.main = {
        layer = "top";
        position = "top";
        height = 36;
        exclusive = true;
        spacing = 20;
        modules-left = [ "niri/workspaces" ];
        modules-right = [
          "custom/input-language"
          "clock#date"
          "clock#time"
        ];
        "custom/input-language" = {
          exec = "${indicator}/bin/ember-input-language";
          return-type = "json";
          restart-interval = 2;
          tooltip = false;
        };
        "niri/workspaces" = {
          format = "●";
          disable-click = true;
        };
        "clock#date" = {
          format = "{:%m-%d}";
          tooltip = false;
        };
        "clock#time" = {
          format = "{:%H:%M}";
          tooltip = false;
        };
      };
      style = ''
        * { border: none; border-radius: 0; font-family: "LXGW WenKai Mono GB"; font-size: 18px; font-weight: 700; min-height: 0; }
        window#waybar { background: transparent; color: ${c.base05}; }
        #workspaces { margin-left: 24px; }
        #workspaces button { padding: 0 4px; margin: 0; background: transparent; color: ${c.base04}; font-size: 9px; }
        #workspaces button.active { color: ${c.base0A}; font-size: 14px; }
        #custom-input-language { color: ${c.base0B}; }
        #custom-input-language.english { color: ${c.base0D}; }
        #custom-input-language.unavailable { color: ${c.base04}; }
        #clock.time { margin-right: 24px; }
      '';
    };
  };
}
