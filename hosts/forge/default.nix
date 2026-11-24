{
  imports = [
    ../../suites/nixos/workstation.nix
    ./power.nix
  ];

  # Steam/Proton stack on the RTX 3090. The desktop's discrete GPU drives the
  # display, so no hybrid PRIME offload wrapper is configured.
  ember.gaming = {
    enable = true;
    nvidiaOffload = false;
  };
}
