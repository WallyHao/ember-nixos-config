# Additional user applications, installed by `just apps`.
# Example: packages = [ "qq" ]; allowedUnfree = [ "qq" ];
# QQ also needs .config/QQ in users/wallyhao/persistence.nix to retain its data.
{
  packages = [
    "zen"
    "obs-studio"
    "zathura"
    "powertop"
    "powerstat"
    "intel-gpu-tools"
    "turbostat"
    "speedtest-cli"
  ];
  allowedUnfree = [ ];
}
