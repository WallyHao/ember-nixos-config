# Additional user applications, installed by `just profile install`.
# Example: packages = [ "qq" ]; allowedUnfree = [ "qq" ];
# QQ also needs .config/QQ in users/wallyhao/persistence.nix to retain its data.
{
  packages = [ "zen" ];
  allowedUnfree = [ ];
}
