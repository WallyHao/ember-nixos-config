{
  config,
  lib,
  pkgs,
  ...
}:
let
  audio = pkgs.writeShellApplication {
    name = "ember-volume";
    runtimeInputs = [ pkgs.wireplumber ];
    text = ''
      case "''${1:-}" in
        up) wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
        down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
        mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
        *) exit 2 ;;
      esac
    '';
  };
  muteAtLogin = pkgs.writeShellApplication {
    name = "ember-mute-at-login";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.wireplumber
    ];
    text = ''
      # WirePlumber can start before the default output has been selected.
      for _ in {1..20}; do
        if wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 2>/dev/null; then
          exit 0
        fi
        sleep 0.5
      done
      echo "Could not mute the default audio output at login." >&2
      exit 1
    '';
  };
  brightness = pkgs.writeShellApplication {
    name = "ember-brightness";
    runtimeInputs = [ pkgs.brightnessctl ];
    text = ''
      case "''${1:-}" in
        up) brightnessctl -q set +5% ;;
        down) brightnessctl -q --min-value=1 set 5%- ;;
        *) exit 2 ;;
      esac
    '';
  };
  session = pkgs.writeShellApplication {
    name = "ember-session";
    runtimeInputs = [
      pkgs.fuzzel
      pkgs.systemd
      pkgs.niri
    ];
    text = ''
      action="''${1:-}"
      if [ -z "$action" ]; then
        action=$(printf 'Lock\nSuspend\nLogout\nReboot\nPoweroff\n' | fuzzel --dmenu --prompt='Session> ') || exit 0
      fi
      case "$action" in
        Lock|lock) exec systemctl --user start ember-lock.service ;;
        Suspend|suspend)
          systemctl --user start ember-lock.service
          exec systemctl suspend
          ;;
        Logout|logout) command=logout ;;
        Reboot|reboot) command=reboot ;;
        Poweroff|poweroff) command=poweroff ;;
        *) exit 0 ;;
      esac
      choice=$(printf 'Yes\nNo\n' | fuzzel --dmenu --lines=2 --prompt="Confirm $command? ") || exit 0
      [ "$choice" = Yes ] || exit 0
      case "$command" in
        logout) exec niri msg action quit --skip-confirmation ;;
        reboot|poweroff) exec systemctl --no-block "$command" ;;
      esac
    '';
  };
  refresh = pkgs.writeShellApplication {
    name = "ember-refresh";
    runtimeInputs = [ pkgs.niri ];
    text = ''
      out="eDP-1"
      mode_bat="1920x1080@60.001"
      mode_ac="1920x1080@144.001"

      if [ -z "''${NIRI_SOCKET:-}" ]; then
        for sock in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/niri.*.sock; do
          [ -e "$sock" ] && { NIRI_SOCKET=$sock; export NIRI_SOCKET; break; }
        done
      fi
      [ -n "''${NIRI_SOCKET:-}" ] || exit 0

      current() {
        niri msg outputs 2>/dev/null | awk '/Current mode:/{print $3 "@" $5; exit}'
      }

      action="''${1:-auto}"
      case "$action" in
        toggle)
          case "$(current)" in
            *@60.001) want="$mode_ac" ;;
            *) want="$mode_bat" ;;
          esac
          ;;
        battery) want="$mode_bat" ;;
        ac) want="$mode_ac" ;;
        auto)
          # Games opt into VRR through niri's window rule; keep 144 Hz for them.
          if niri msg windows 2>/dev/null | grep -qE 'App ID: "(gamescope|steam_app_)'; then
            exit 0
          fi
          if [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 1)" = "0" ]; then
            want="$mode_bat"
          else
            want="$mode_ac"
          fi
          ;;
        *) exit 2 ;;
      esac

      [ "$(current)" = "$want" ] || niri msg output "$out" mode "$want" || true
    '';
  };
  control = pkgs.writeShellApplication {
    name = "ember-control";
    runtimeInputs = [
      pkgs.fuzzel
      pkgs.foot
      pkgs.networkmanager
      pkgs.pavucontrol
      pkgs.mako
      session
    ];
    text = ''
      choice=$(printf 'Network\nAudio devices\nToggle Do Not Disturb\nLock\nSession\n' | fuzzel --dmenu --prompt='Control> ') || exit 0
      case "$choice" in
        Network) exec foot -e nmtui ;;
        'Audio devices') exec pavucontrol ;;
        'Toggle Do Not Disturb') exec makoctl mode -t do-not-disturb ;;
        Lock) exec ember-session lock ;;
        Session) exec ember-session ;;
      esac
    '';
  };
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.packages = [
      audio
      brightness
      session
      control
      refresh
    ];

    systemd.user.services.ember-mute-at-login = {
      Unit = {
        Description = "Mute the default audio output at graphical login";
        PartOf = [ "graphical-session.target" ];
        Wants = [ "wireplumber.service" ];
        # Target dependencies otherwise run before the target by default.
        # Waiting for an audio sink here used to hold up Waybar and portals
        # for the entire retry window (and could delay audio discovery itself).
        After = [
          "graphical-session.target"
          "wireplumber.service"
        ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe muteAtLogin;
        RemainAfterExit = true;
        TimeoutStartSec = 12;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Drop to 60 Hz on battery, restore 144 Hz on AC. The timer only acts on a
    # power-source change, so it does not fight manual `ember-refresh` calls.
    systemd.user.services.ember-refresh = {
      Unit = {
        Description = "Match eDP-1 refresh rate to power source";
        PartOf = [ "graphical-session.target" ];
        After = [ "niri.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${refresh}/bin/ember-refresh auto";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    systemd.user.timers.ember-refresh = {
      Unit = {
        Description = "Poll power source for eDP-1 refresh rate";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30s";
        Unit = "ember-refresh.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
    services.mako.settings."mode=do-not-disturb".invisible = true;
  };
}
