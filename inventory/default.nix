{
  hosts.ember = {
    system = "x86_64-linux";
    hostName = "ember";
    stateVersion = "26.11";
    hostModule = ../hosts/laptop;
    physicalHardwareModule = ../hosts/laptop/hardware.nix;
    users = [ "wallyhao" ];
    storage = import ../hosts/laptop/storage-spec.nix;
  };

  users.wallyhao = {
    name = "wallyhao";
    uid = 1000;
    home = "/home/wallyhao";
    loginShell = "zsh";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    initialHashedPassword = import ../users/wallyhao/bootstrap-password.nix;
    homeModule = ../users/wallyhao/home.nix;
    homeStateVersion = "26.11";
    persistenceModule = ../users/wallyhao/persistence.nix;
  };
}
