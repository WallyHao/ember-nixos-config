{
  imports = [
    ../../suites/nixos/workstation.nix
    ./power.nix
  ];

  # Steam/Proton stack on the RTX 4060. VM checks override this to false.
  ember.gaming = {
    enable = true;
    # Hybrid laptop: i915 drives the panel, the RTX 4060 renders on request.
    nvidiaOffload = true;
  };
}
