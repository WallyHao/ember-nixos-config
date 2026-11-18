{
  pkgs,
  nix,
  esp,
}:
pkgs.writeShellApplication {
  name = "ember-nix-gc";
  text = ''
    exec ${pkgs.python3}/bin/python3 -EsB ${./garbage.py} ${nix} ${pkgs.lib.escapeShellArg esp}
  '';
}
