{ modifier, actions }:
let
  bind =
    title: action:
    {
      _props = {
        hotkey-overlay-title = title;
      }
      // (action._props or { });
    }
    // builtins.removeAttrs action [ "_props" ];

  spawn = title: command: bind title { spawn = command; };

  workspaceKey = index: if index == 10 then "0" else toString index;

  workspaceBinds = builtins.listToAttrs (
    builtins.genList (
      index:
      let
        key = workspaceKey (index + 1);
      in
      {
        name = "${modifier}+${key}";
        value = bind "Focus workspace ${toString (index + 1)}" {
          focus-workspace = index + 1;
        };
      }
    ) 10
    ++ builtins.genList (
      index:
      let
        key = workspaceKey (index + 1);
      in
      {
        name = "${modifier}+Shift+${key}";
        value = bind "Move window to workspace ${toString (index + 1)}" {
          move-window-to-workspace = index + 1;
        };
      }
    ) 10
  );
in
{
  "${modifier}+Return" = spawn "Open terminal" actions.terminal;
  "${modifier}+D" = spawn "Open application launcher" actions.launcher;
  "${modifier}+V" = spawn "Open clipboard history" actions.clipboard;
  "${modifier}+C" = spawn "Toggle quick settings" actions.controlCenter;
  "${modifier}+P" = spawn "Open control menu" [ "ember-control" ];
  "${modifier}+Y" = spawn "Open Yazi" actions.fileManager;

  "${modifier}+Q" = bind "Close window" { close-window = { }; };
  "${modifier}+Tab" = bind "Show workspace overview" {
    _props.repeat = false;
    toggle-overview = { };
  };
  "${modifier}+Shift+Slash" = bind "Show all keyboard shortcuts" {
    _props.repeat = false;
    show-hotkey-overlay = { };
  };
  "${modifier}+F" = bind "Toggle maximize to screen edges" {
    _props.repeat = false;
    maximize-window-to-edges = { };
  };
  "${modifier}+G" = bind "Toggle workspace centering" {
    _props.repeat = false;
    center-column = { };
  };
  "${modifier}+S" = bind "Capture full screen" {
    _props.repeat = false;
    screenshot-screen._props.show-pointer = false;
  };
  "${modifier}+Shift+S" = bind "Capture screen region" {
    _props.repeat = false;
    screenshot._props.show-pointer = false;
  };

  "${modifier}+Left" = bind "Focus column left" { focus-column-left = { }; };
  "${modifier}+Right" = bind "Focus column right" { focus-column-right = { }; };
  "${modifier}+Up" = bind "Focus window up" { focus-window-up = { }; };
  "${modifier}+Down" = bind "Focus window down" { focus-window-down = { }; };
  "${modifier}+Shift+Left" = bind "Move column left" { move-column-left = { }; };
  "${modifier}+Shift+Right" = bind "Move column right" { move-column-right = { }; };

  "${modifier}+Shift+E" = spawn "Confirm logout" [
    "ember-session"
    "logout"
  ];
  "${modifier}+L" = spawn "Lock screen" [
    "systemctl"
    "--user"
    "start"
    "ember-lock.service"
  ];
  "${modifier}+Shift+R" = spawn "Open session actions (reboot confirmation)" (
    actions.session ++ [ "reboot" ]
  );
  "${modifier}+Shift+T" = spawn "Open session actions (shutdown confirmation)" (
    actions.session ++ [ "poweroff" ]
  );

  "XF86AudioRaiseVolume" = bind "Raise volume" {
    _props.allow-when-locked = true;
    spawn = actions.volumeUp;
  };
  "XF86AudioLowerVolume" = bind "Lower volume" {
    _props.allow-when-locked = true;
    spawn = actions.volumeDown;
  };
  "XF86AudioMute" = bind "Mute audio" {
    _props.allow-when-locked = true;
    spawn = actions.volumeMute;
  };
  "XF86MonBrightnessUp" = bind "Raise brightness" {
    _props.allow-when-locked = true;
    spawn = actions.brightnessUp;
  };
  "XF86MonBrightnessDown" = bind "Lower brightness" {
    _props.allow-when-locked = true;
    spawn = actions.brightnessDown;
  };
}
// workspaceBinds
