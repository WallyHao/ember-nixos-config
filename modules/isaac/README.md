# Isaac

Isaac Sim / Isaac Lab support, adapted from the Folio module. The host option
`ember.isaac.enable` adds the user environment; actual simulators and training
environments are installed explicitly into the user's home.

```sh
isaac-doctor --stage preflight
isaac-setup                 # prepare and validate dependencies
isaac-setup --accept-eula   # accept the NVIDIA EULA and activate the environment
isaac-status
isaac-lab --help
```

The FHS wrapper provides CPython 3.12, CUDA/Vulkan libraries and the build
toolchain expected by Isaac Lab. The default workspace is
`~/Workspace/isaac/IsaacLab`; environments, manifests, validation reports and
GC roots live under the retained Folio namespace:

```text
~/.local/share/folio/isaac
~/.local/state/folio/isaac
~/.cache/folio/isaac
```

These paths are preserved in `users/wallyhao/persistence.nix`. The profile is
pinned in `src/versions.json`; changing it requires rebuilding the module and
re-running `isaac-setup`. `isaac-doctor` stages require a working NVIDIA driver
and Vulkan; VM checks disable the module because they have no real GPU.
