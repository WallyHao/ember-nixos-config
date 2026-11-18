# Regular `*.nix` modules of one directory, in name order. Non-recursive, and
# `default.nix` / `_`-prefixed files are skipped. Every file must be a module:
# `modules/niri/binds.nix` takes its own arguments and keeps an explicit list.
dir:
let
  entries = builtins.readDir dir;
  isModule =
    name:
    entries.${name} == "regular"
    && name != "default.nix"
    && builtins.substring 0 1 name != "_"
    && builtins.match ".*\\.nix" name != null;
in
map (name: dir + "/${name}") (builtins.filter isModule (builtins.attrNames entries))
