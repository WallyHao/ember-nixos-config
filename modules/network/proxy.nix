{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ember.proxy;
  state = "/var/lib/hearth-proxy";
  yaml = pkgs.formats.yaml { };
  providerHealthCheck = {
    enable = true;
    url = cfg.healthCheckUrl;
    interval = 60;
    lazy = false;
    "expected-status" = "204";
  };
  checkUplink = import ../maintenance/check-uplink.nix {
    inherit lib pkgs;
    urls = cfg.directCheckUrls;
  };
  prepareData = ''
    ln -sfn ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat ${state}/GeoIP.dat
    ln -sfn ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat ${state}/GeoSite.dat
  '';
  proxyConfig = yaml.generate "ember-mihomo.yaml" {
    mode = "rule";
    "mixed-port" = 7890;
    "allow-lan" = false;
    "bind-address" = "127.0.0.1";
    "log-level" = "warning";
    ipv6 = true;
    "find-process-mode" = "off";
    "external-controller-unix" = "/run/ember-proxy/controller.sock";
    "geodata-mode" = true;
    "geo-auto-update" = false;
    profile."store-selected" = true;
    tun = {
      enable = true;
      device = "ember-tun";
      stack = "mixed";
      "auto-route" = true;
      "auto-redirect" = true;
      "auto-detect-interface" = true;
      "strict-route" = false;
      "dns-hijack" = [
        "any:53"
        "tcp://any:53"
      ];
    };
    dns = {
      enable = true;
      listen = "127.0.0.1:1053";
      ipv6 = true;
      "enhanced-mode" = "fake-ip";
      "fake-ip-range" = "198.18.0.1/16";
      "fake-ip-filter" = [
        "*.lan"
        "*.local"
        "localhost"
      ];
      "default-nameserver" = [
        "223.5.5.5"
        "119.29.29.29"
      ];
      nameserver = [
        "https://dns.alidns.com/dns-query"
        "https://doh.pub/dns-query"
      ];
      "proxy-server-nameserver" = [ "https://dns.alidns.com/dns-query" ];
    };
    "proxy-providers".local = {
      type = "file";
      path = "${state}/providers.yaml";
      "health-check" = providerHealthCheck;
    };
    "proxy-groups" = [
      {
        name = "HK-AUTO";
        type = "url-test";
        use = [ "local" ];
        filter = cfg.hongKongNodeFilter;
        "exclude-type" = "direct";
        "empty-fallback" = "REJECT";
        url = cfg.healthCheckUrl;
        "expected-status" = "204";
        interval = 60;
        tolerance = 0;
      }
      {
        name = "NODES";
        type = "url-test";
        use = [ "local" ];
        url = cfg.healthCheckUrl;
        "expected-status" = "204";
        interval = 60;
        tolerance = 100;
      }
      {
        name = "AUTO";
        type = "fallback";
        proxies = [
          "HK-AUTO"
          "NODES"
          "DIRECT"
        ];
        url = cfg.healthCheckUrl;
        "expected-status" = "204";
        lazy = false;
        interval = 60;
      }
      # Manual override above AUTO: defaults to AUTO, can pin one node or DIRECT.
      {
        name = "SELECT";
        type = "select";
        use = [ "local" ];
        proxies = [
          "AUTO"
          "DIRECT"
        ];
      }
    ];
    rules = [
      "DOMAIN-SUFFIX,local,DIRECT"
      "DOMAIN-SUFFIX,lan,DIRECT"
      "IP-CIDR,127.0.0.0/8,DIRECT,no-resolve"
      "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve"
      "IP-CIDR,172.16.0.0/12,DIRECT,no-resolve"
      "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"
      "IP-CIDR,169.254.0.0/16,DIRECT,no-resolve"
      "IP-CIDR6,::1/128,DIRECT,no-resolve"
      "IP-CIDR6,fc00::/7,DIRECT,no-resolve"
      "IP-CIDR6,fe80::/10,DIRECT,no-resolve"
      "GEOSITE,cn,DIRECT"
      "GEOIP,CN,DIRECT,no-resolve"
      "MATCH,SELECT"
    ];
  };
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
  render = pkgs.writeShellScript "ember-render-proxy" ''
    set -eu
    ${prepareData}
    if test -s ${state}/sources.yaml; then
      source=${state}/sources.yaml
    else
      source=${state}/providers.yaml
    fi
    exec ${python}/bin/python3 ${./proxy-data.py} assemble ${proxyConfig} "$source" ${state}/config.yaml ${state}
  '';
  control = pkgs.writeShellApplication {
    name = "ember-proxy-control";
    text = ''
      exec ${pkgs.python3}/bin/python3 -EsB ${./proxy-control.py} \
        ${lib.getExe pkgs.curl} ${lib.getExe' config.systemd.package "systemctl"} ${state} "$@"
    '';
  };
  panel = pkgs.writeShellApplication {
    name = "ember-proxy-panel";
    text = ''
      if [[ "$#" -eq 1 && "$1" == status ]]; then
        exec ${lib.getExe control} status
      fi
      exec ${config.security.wrapperDir}/pkexec --disable-internal-agent ${lib.getExe control} "$@"
    '';
  };
  panelPolicy = pkgs.writeTextDir "share/polkit-1/actions/org.ember.proxy.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
    <policyconfig>
      <action id="org.ember.proxy.control">
        <description>Manage the Ember proxy</description>
        <message>Administrator authentication is required to manage the Ember proxy</message>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>auth_admin_keep</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">${lib.getExe control}</annotate>
      </action>
    </policyconfig>
  '';
  cli = pkgs.writeShellApplication {
    name = "ember-proxy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.util-linux
      pkgs.mihomo
    ];
    text = ''
      case "''${1:-status}" in
        status)
          systemctl --no-pager status ember-proxy.service || true
          ;;
        on|off|nodes)
          exec sudo ${lib.getExe control} "$1"
          ;;
        check)
          sudo ${render}
          sudo sh -c 'umask 077; ${pkgs.mihomo}/bin/mihomo -t -d ${state} -f ${state}/config.yaml > ${state}/validation.log 2>&1' || { echo 'Proxy validation failed; see the private validation.log.' >&2; exit 1; }
          echo 'Proxy configuration is valid.' 
          ;;
        import)
          test "$#" -eq 2 || { echo 'Usage: ember-proxy import /path/to/provider.yaml' >&2; exit 2; }
          exec sudo flock /run/ember-proxy-import.lock "$0" _import "$(realpath -- "$2")"
          ;;
        _import)
          test "$(id -u)" -eq 0
          umask 077
          candidate=$(mktemp ${state}/source.XXXXXX)
          trap 'rm -f "$candidate"' EXIT
          ${python}/bin/python3 ${./proxy-data.py} normalize "$2" "$candidate"
          had_source=false
          if test -f ${state}/sources.yaml; then
            cp ${state}/sources.yaml ${state}/sources.previous
            had_source=true
          fi
          mv "$candidate" ${state}/sources.yaml
          if ! ${render} || ! mihomo -t -d ${state} -f ${state}/config.yaml > ${state}/validation.log 2>&1; then
            if "$had_source"; then
              mv ${state}/sources.previous ${state}/sources.yaml
            else
              rm -f ${state}/sources.yaml
            fi
            ${render} || true
            echo 'Source rejected; prior source retained. Diagnostics are private in the proxy state directory.' >&2
            exit 1
          fi
          rm -f ${state}/sources.previous
          rm -f ${state}/disabled
          systemctl restart ember-proxy.service
          ;;
        select)
          test "$#" -eq 2 || { echo 'Usage: ember-proxy select NAME' >&2; exit 2; }
          exec sudo ${lib.getExe control} select "$2"
          ;;
        *) echo 'Usage: ember-proxy {status|on|off|check|import FILE|nodes|select NAME}' >&2; exit 2 ;;
      esac
    '';
  };
in
{
  options.ember.proxy = {
    enable = lib.mkEnableOption "Ember managed Mihomo TUN proxy" // {
      default = true;
    };
    healthCheckUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://www.gstatic.com/generate_204";
      description = "URL returning HTTP 204 for Mihomo node selection and fallback.";
    };
    directCheckUrls = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      default = [
        "https://connect.rom.miui.com/generate_204"
        "https://connectivitycheck.platform.hicloud.com/generate_204"
      ];
      description = "Direct uplink probes before starting Mihomo. One HTTP 204 is sufficient.";
    };
    hongKongNodeFilter = lib.mkOption {
      type = lib.types.str;
      default = "(?i)🇭🇰|香港|Hong[ _-]*Kong|(?:^|[^a-z])HK(?:[^a-z]|$)";
      description = "Mihomo regular expression identifying Hong Kong nodes by name.";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cli
      (pkgs.writeShellScriptBin "hearth-proxy" ''exec ${cli}/bin/ember-proxy "$@"'')
    ]
    ++ lib.optional config.ember.desktop.enable panelPolicy;
    security.polkit.enablePkexecWrapper = lib.mkIf config.ember.desktop.enable true;
    environment.etc."ember/proxy-panel" = lib.mkIf config.ember.desktop.enable {
      source = lib.getExe panel;
    };
    environment.etc."ember/mihomo.yaml".source = proxyConfig;
    boot.kernelModules = [ "tun" ];
    systemd.tmpfiles.rules = [ "d ${state} 0700 root root -" ];
    preservation.preserveAt."/persist".directories = [
      {
        directory = state;
        mode = "0700";
      }
    ];
    systemd.timers.ember-proxy = {
      description = "Retry automatic proxy startup after the uplink becomes usable";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2s";
        OnCalendar = "*:*:0/30";
        AccuracySec = "1s";
      };
    };
    systemd.services.ember-proxy = {
      description = "Ember automatic proxy (Mihomo TUN)";
      aliases = [ "hearth-proxy.service" ];
      wants = [
        "NetworkManager.service"
        "systemd-resolved.service"
      ];
      after = [
        "NetworkManager.service"
        "systemd-resolved.service"
      ];
      unitConfig = {
        ConditionPathExists = [
          "|${state}/providers.yaml"
          "|${state}/sources.yaml"
          "!${state}/disabled"
        ];
        RequiresMountsFor = [ state ];
      };
      preStart = ''
        umask 077
        touch ${state}/service.log
        chmod 600 ${state}/service.log
        ${render}
      '';
      serviceConfig = {
        ExecCondition = checkUplink;
        ExecStart = "${pkgs.mihomo}/bin/mihomo -d ${state} -f ${state}/config.yaml";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "hearth-proxy";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "ember-proxy";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        # Runtime errors can contain private subscription URLs; keep them out of the journal.
        StandardOutput = "append:${state}/service.log";
        StandardError = "inherit";
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
        ];
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
      };
    };
  };
}
