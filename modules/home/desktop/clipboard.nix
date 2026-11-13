{
  config,
  lib,
  pkgs,
  ...
}:
let
  store = pkgs.writeScript "ember-clipboard-store" ''
    #!${pkgs.python3}/bin/python3
    import os, subprocess, sys
    if os.environ.get("CLIPBOARD_STATE", "data") != "data":
        sys.exit(0)
    data = sys.stdin.buffer.read(8 * 1024 * 1024 + 1)
    if not data or len(data) > 8 * 1024 * 1024:
        sys.exit(0)
    subprocess.run(["${pkgs.cliphist}/bin/cliphist", "-db-path", os.environ["XDG_RUNTIME_DIR"] + "/ember-clipboard/history.db", "-max-items", "100", "store"], input=data, check=True)
  '';
  picker = pkgs.writeShellApplication {
    name = "ember-clipboard";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.wl-clipboard
      pkgs.fuzzel
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?Active Wayland session required}"
      db="$XDG_RUNTIME_DIR/ember-clipboard/history.db"
      [ -f "$db" ] || exit 0
      selection=$(cliphist -db-path "$db" list | fuzzel --dmenu --prompt='Clipboard> ') || exit 0
      [ -n "$selection" ] || exit 0
      printf '%s\n' "$selection" | cliphist -db-path "$db" decode | wl-copy
    '';
  };
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.packages = [ picker ];
    services.wl-clip-persist = {
      enable = true;
      clipboardType = "regular";
      systemdTargets = [ "graphical-session.target" ];
    };
    systemd.user.services.ember-clipboard-watch = {
      Unit = {
        Description = "Ember session-only clipboard history";
        PartOf = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
          "niri.service"
        ];
      };
      Service = {
        RuntimeDirectory = "ember-clipboard";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${store}";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
