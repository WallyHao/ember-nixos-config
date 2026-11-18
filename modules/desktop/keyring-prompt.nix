{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;
  appId = "org.ember.KeyringPrompt";
  gtkConfig = pkgs.writeTextDir "gtk-3.0/gtk.css" ''
    dialog.background, headerbar {
      background: ${c.base00};
      color: ${c.base05};
    }

    dialog.background {
      font-family: "${config.stylix.fonts.sansSerif.name}", sans-serif;
      font-size: 15px;
    }

    headerbar {
      border-color: ${c.base02};
      box-shadow: none;
    }

    .dialog-vbox {
      padding: 16px 18px;
    }

    .dialog-vbox grid {
      min-width: 390px;
    }

    .dialog-action-area {
      margin-top: 14px;
    }

    entry, .dialog-action-area button {
      min-height: 28px;
      padding: 4px 12px;
      background: ${c.base01};
      color: ${c.base05};
      border: 1px solid ${c.base03};
      border-radius: 8px;
      box-shadow: none;
      text-shadow: none;
    }

    entry:focus, button:focus, checkbutton:focus check {
      border-color: ${c.base0A};
    }

    entry selection, .dialog-action-area button.default {
      background: ${c.base0A};
      color: ${c.base00};
      border-color: ${c.base0A};
    }

    .dialog-action-area button:hover {
      background: ${c.base02};
    }

    .dialog-action-area button.default:hover {
      background: ${c.base06};
    }

    .dialog-action-area button:disabled {
      opacity: 0.55;
    }

    check:checked, progressbar progress {
      background: ${c.base0A};
      color: ${c.base00};
      border-color: ${c.base0A};
    }
  '';
  prompter = pkgs.writeShellScript "ember-keyring-prompt" ''
    export GTK_THEME=Adwaita:dark
    export XDG_CONFIG_HOME=${gtkConfig}
    exec ${pkgs.gcr_3}/libexec/gcr-prompter --name=${appId}
  '';
  # Session D-Bus loads per-user activators before the system package entries.
  service = kind: {
    name = "dbus-1/services/org.gnome.keyring.${kind}Prompter.service";
    value.text = ''
      [D-BUS Service]
      Name=org.gnome.keyring.${kind}Prompter
      Exec=${prompter}
    '';
  };
in
{
  config = lib.mkIf (config.ember.desktop.enable && osConfig.services.gnome.gnome-keyring.enable) {
    xdg.dataFile = builtins.listToAttrs (
      map service [
        "System"
        "Private"
      ]
    );

    wayland.windowManager.niri.settings._children = [
      {
        window-rule._children = [
          {
            match._props.app-id = "^org[.]ember[.]KeyringPrompt$";
            open-floating = true;
          }
        ];
      }
    ];
  };
}
