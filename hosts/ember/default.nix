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

  # Isaac Sim / Isaac Lab is a host-level feature: the FHS environment is
  # useful on both NVIDIA machines, while installs stay in the user's home.
  ember.isaac.enable = true;
}
