{
  lib,
  pkgs,
  ...
}:
let
  port = 7373;
  shareDir = "/home/wallyhao/Downloads/Share";
  authDir = "/home/wallyhao/.local/state/file-drop";
  authFile = "${authDir}/auth";

  # Credentials are read from a runtime file: the password must not reach the
  # Nix store, the unit's command line, or any generated documentation.
  ensureAuth = pkgs.writeShellScript "ember-file-drop-auth" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    if [ ! -s ${authFile} ]; then
      umask 077
      password=$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | cut -c 1-16)
      printf 'wallyhao:%s\n' "$password" > ${authFile}
    fi
  '';
in
{
  networking.firewall.allowedTCPPorts = [ port ];

  systemd.tmpfiles.rules = [
    "d ${shareDir} 0755 wallyhao users -"
    "d ${authDir} 0700 wallyhao users -"
  ];

  systemd.services.file-drop = {
    description = "Ember LAN file drop (miniserve)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "wallyhao";
      Group = "users";
      ExecStartPre = ensureAuth;
      ExecStart = "${lib.getExe pkgs.miniserve} ${shareDir} -p ${toString port} -u -P --auth-file ${authFile} -t 'Ember 文件互传'";
      Restart = "always";
      RestartSec = 2;
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      ReadWritePaths = [
        shareDir
        authDir
      ];
    };
  };
}
