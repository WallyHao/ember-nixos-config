{
  lib,
  inventory,
}:
let
  checked = import ../inventory/schema.nix {
    inherit lib inventory;
  };
in
{
  hosts = checked.hosts;
  users = checked.users;
}
