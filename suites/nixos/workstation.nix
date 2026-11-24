{
  imports = [
    ./base.nix
    ./desktop.nix
  ];

  services.xserver.enable = false;
}
