{
  lib,
}:
{
  # Keep unfree admission explicit: hardware drivers plus applications the
  # user deliberately allows in the same file as their software selection.
  allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) (
      [
        "nvidia-x11"
        "nvidia-settings"
      ]
      ++ (import ./selection/user-packages.nix).allowedUnfree
    );
}
