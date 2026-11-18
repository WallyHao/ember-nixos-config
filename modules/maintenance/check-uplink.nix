{
  lib,
  pkgs,
  urls,
}:
pkgs.writeShellScript "ember-proxy-check-uplink" ''
  for url in ${lib.escapeShellArgs urls}; do
    if status=$(${pkgs.curl}/bin/curl -q --noproxy '*' --silent \
      --connect-timeout 2 --max-time 4 --output /dev/null --write-out '%{http_code}' "$url") &&
      test "$status" = 204; then
      exit 0
    fi
  done
  echo 'Proxy start deferred: waiting for direct Internet access.' >&2
  exit 1
''
