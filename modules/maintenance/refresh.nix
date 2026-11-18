{
  config,
  lib,
  pkgs,
}:
let
  cfg = config.ember.proxy;
  backendConfig = pkgs.writeText "ember-refresh-settings.json" (
    builtins.toJSON {
      nmcli = "${pkgs.networkmanager}/bin/nmcli";
      systemctl = "${config.systemd.package}/bin/systemctl";
      uplink = import ./check-uplink.nix {
        inherit lib pkgs;
        urls = cfg.directCheckUrls;
      };
      healthUrl = cfg.healthCheckUrl;
      proxyEnabled = cfg.enable;
      nix = config.nix.package;
      esp = config.boot.loader.efi.efiSysMountPoint;
    }
  );
  backend = pkgs.writeShellApplication {
    name = "ember-refresh-backend";
    text = ''
      exec ${pkgs.python3}/bin/python3 -EsB ${./.}/backend.py ${backendConfig} "$@"
    '';
  };
in
pkgs.writeShellApplication {
  name = "ember-refresh";
  text = ''
    exec ${pkgs.python3}/bin/python3 -EsB ${./.}/menu.py ${pkgs.fzf}/bin/fzf ${lib.getExe backend} "$@"
  '';
}
