{
  imports = [
    ../../suites/nixos/laptop.nix
    ./power.nix
    ./nixos-cli.nix
  ];

  # The gaming stack is opt-in on this host even though modules/gaming.nix
  # defaults the switch to true. Flip it back when games are actually wanted.
  ember.gaming.enable = false;
}
