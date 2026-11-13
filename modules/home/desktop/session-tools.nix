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
    ];
    services.mako.settings."mode=do-not-disturb".invisible = true;
  };
}
