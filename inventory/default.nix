{
  hosts.ember = {
    system = "x86_64-linux";
    hostName = "ember";
    stateVersion = "26.11";
    hostModule = ../hosts/ember;
    # Shared driver closure first, then the machine's observed facts and
    # overrides. This is the only place that selects hardware policy.
    hardwareModules = [
      ../hosts/hardware/portable.nix
      ../hosts/ember/hardware.nix
    ];
    users = [ "wallyhao" ];
    storage = import ../hosts/ember/storage-spec.nix;
  };

  # AMD Ryzen 7 9700X / RTX 3090 desktop recorded in the Folio configuration.
  # Storage stays unbound until its disk identity and layout are inspected, so
  # deployment remains gated in lib/deployment.nix.
  hosts.forge = {
    system = "x86_64-linux";
    hostName = "forge";
    stateVersion = "26.11";
    hostModule = ../hosts/forge;
    hardwareModules = [
      ../hosts/hardware/portable.nix
      ../hosts/forge/hardware.nix
    ];
    users = [ "wallyhao" ];
    storage = import ../hosts/forge/storage-spec.nix;
  };

  users.wallyhao = {
    name = "wallyhao";
    uid = 1000;
    home = "/home/wallyhao";
    loginShell = "zsh";
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
    ];
    initialHashedPassword = import ../users/wallyhao/bootstrap-password.nix;
    homeModule = ../users/wallyhao/home.nix;
    homeStateVersion = "26.11";
    persistenceModule = ../users/wallyhao/persistence.nix;
  };
}
