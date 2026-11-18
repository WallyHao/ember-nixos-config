{
  config,
  lib,
  pkgs,
  ...
}:
let
  script = pkgs.writeShellApplication {
    name = "niri-single-window-width";
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
    systemd.user.services.niri-single-window-width = {
      Unit = {
        Description = "Expand the only window on the focused Niri workspace to full width";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
      };
      Service = {
        ExecStart = "${script}/bin/niri-single-window-width";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "niri.service" ];
    };

    home.activation.emberNiriSingleWindow = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet niri.service; then
        ${pkgs.systemd}/bin/systemctl --user daemon-reload || true
        ${pkgs.systemd}/bin/systemctl --user start --no-block niri-single-window-width.service || true
      fi
    '';
  };
}
