{
  lib,
  ...
}:
{
  nixpkgs.config = import ../../../software/policy.nix {
    inherit lib;
  };
}
