{
  config,
  lib,
  pkgs,
  ...
}:
let
  script = pkgs.writeShellApplication {
    name = "niri-single-window-fullscreen";
    runtimeInputs = with pkgs; [
      niri
      jq
      coreutils
    ];
    text = builtins.readFile ./single-window.sh;
  };
in
{
  config = lib.mkIf config.ember.desktop.enable {
    systemd.user.services.niri-single-window-fullscreen = {
      Unit = {
        Description = "Maximize the only window on the focused Niri workspace";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
      };
      Service = {
        ExecStart = "${script}/bin/niri-single-window-fullscreen";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "niri.service" ];
    };

    home.activation.emberNiriSingleWindow = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet niri.service; then
        ${pkgs.systemd}/bin/systemctl --user daemon-reload || true
        ${pkgs.systemd}/bin/systemctl --user start --no-block niri-single-window-fullscreen.service || true
      fi
    '';
  };
}
