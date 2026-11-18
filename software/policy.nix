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

        # Steam is installed as a system component by modules/gaming.nix:
        # the 32-bit graphics stack, pressure-vessel helpers and controller
        # udev rules cannot come from the separate user profile. The runtime
        # and the unwrapped client carry the unfree Steam licence.
        "steam"
        "steam-unwrapped"
      ]
      ++ (import ./selection/user-packages.nix).allowedUnfree
    );
}
