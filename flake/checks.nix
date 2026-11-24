{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      inventory = import ../inventory;
      deployment = import ../lib/deployment.nix {
        inherit inventory;
      };
      evaluated = import ../lib/eval-inventory.nix {
        lib = inputs.nixpkgs.lib;
        inherit inventory;
      };
      host = evaluated.hosts.ember;
      forge = evaluated.hosts.forge;

      preview = (import ../lib/mk-host.nix) {
        inherit inputs inventory;
        hostName = "ember";
        hardwareModules = host.hardwareModules;
        storageModule = ../tests/fixtures/storage.nix;
      };

      forgePreview = (import ../lib/mk-host.nix) {
        inherit inputs inventory;
        hostName = "forge";
        hardwareModules = forge.hardwareModules;
        storageModule = ../tests/fixtures/storage.nix;
      };

      previewToplevel = preview.system.config.system.build.toplevel;
      previewCfg = preview.system.config;
      forgeToplevel = forgePreview.system.config.system.build.toplevel;
      forgeCfg = forgePreview.system.config;
      forgeHmCfg = forgeCfg.home-manager.users.wallyhao;
      realCfg = self.nixosConfigurations.ember.config;
      hmCfg = previewCfg.home-manager.users.wallyhao;
      niriConfig = hmCfg.xdg.configFile."niri/config.kdl".source;
      footConfig = hmCfg.xdg.configFile."foot/foot.ini".source;
      nixvimInit = hmCfg.programs.nixvim.build.initFile;
      nixvimPkg = hmCfg.programs.nixvim.build.package;

      evalResults = import ../tests/eval/default.nix {
        inherit
          inputs
          inventory
          deployment
          ;
      };
      evalJson = builtins.toJSON evalResults;

      vmArgs = {
        inherit
          inputs
          pkgs
          inventory
          ;
      };
    in
    {
      packages.system-preview = previewToplevel;
      packages.system-preview-forge = forgeToplevel;
      packages.migration-tool = pkgs.writeShellApplication {
        name = "ember-migrate-folio-data";
        runtimeInputs = [ pkgs.util-linux ];
        text = ''
          exec ${
            pkgs.python3.withPackages (ps: [ ps.pyyaml ])
          }/bin/python3 ${../scripts/migrate-folio-data.py} --normalizer ${../modules/network/proxy-data.py} "$@"
        '';
      };

      checks = {
        storage-layout =
          assert realCfg.disko.devices.disk.main.device == host.storage.targetDisk;
          assert realCfg.fileSystems."/".fsType == "tmpfs";
          assert realCfg.fileSystems."/nix".device == realCfg.fileSystems."/persist".device;
          assert realCfg.fileSystems."/nix".neededForBoot;
          assert realCfg.fileSystems."/persist".neededForBoot;
          assert realCfg.swapDevices == [ ];
          pkgs.runCommand "ember-storage-layout" { nativeBuildInputs = [ pkgs.bash ]; } ''
            # Parse only: never execute the real disk's partitioning script.
            bash -n ${realCfg.system.build.diskoScript}
            mkdir -p $out
            cp ${realCfg.system.build.diskoScript} $out/disko-script-reviewed-only
          '';

        eval-contracts = pkgs.runCommand "ember-eval-contracts" { } ''
          printf '%s\n' '${evalJson}' > $out
        '';

        refresh = pkgs.runCommand "ember-refresh-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          touch "$TMPDIR/nixos-cli.toml"
          NIXOS_CLI_CONFIG="$TMPDIR/nixos-cli.toml" ${pkgs.lib.getExe realCfg.programs.nixos-cli.package} --version
          test -f ${realCfg.systemd.units."ember-nix-gc.service".unit}/ember-nix-gc.service
          python3 -B ${../tests/refresh.py} ${../modules/maintenance}
          touch $out
        '';

        desktop-config =
          pkgs.runCommand "ember-desktop-config"
            {
              nativeBuildInputs = [
                pkgs.niri
                pkgs.foot
                pkgs.zsh
                nixvimPkg
              ];
            }
            ''
              export HOME=$TMPDIR
              mkdir -p "$HOME/.local/state"
              niri validate --config ${niriConfig}
              foot --check-config --config ${footConfig}
              ${builtins.head hmCfg.systemd.user.services.ember-quick-settings.Service.ExecStart} --version
              zsh -n ${../modules/terminal/resources/p10k.zsh}
              zsh -n ${hmCfg.home.file."./.zshrc".source}
              nvim --headless -u ${nixvimInit} -c 'set number?' -c 'qa!' 2>&1 | grep -q 'number'
              touch $out
            '';

        vm-accounts = import ../tests/vm/accounts.nix vmArgs;
        vm-persistence = import ../tests/vm/persistence.nix vmArgs;
        vm-offline-link = import ../tests/vm/offline-link.nix vmArgs;
        vm-desktop = import ../tests/vm/desktop.nix vmArgs;
        vm-user-environment = import ../tests/vm/user-environment.nix vmArgs;
        vm-connectivity = import ../tests/vm/connectivity.nix vmArgs;
        vm-file-drop = import ../tests/vm/file-drop.nix vmArgs;

        # Cross-machine contract: the shared closure provides both vendors'
        # drivers, while host overlays own PRIME, DRM and KVM policy.
        hardware-profiles =
          assert forgeCfg.hardware.cpu.intel.updateMicrocode;
          assert forgeCfg.hardware.cpu.amd.updateMicrocode;
          assert builtins.elem "i915" forgeCfg.boot.initrd.kernelModules;
          assert builtins.elem "amdgpu" forgeCfg.boot.initrd.kernelModules;
          assert forgeCfg.hardware.nvidia.open;
          assert builtins.elem "nvidia" forgeCfg.services.xserver.videoDrivers;
          assert builtins.elem "amdgpu" forgeCfg.services.xserver.videoDrivers;
          assert !forgeCfg.hardware.nvidia.prime.offload.enable;
          assert forgeCfg.ember.hardware.kvmModule == "kvm-amd";
          assert forgeHmCfg.ember.desktop.ignoreDrmDevice == null;
          assert previewCfg.ember.hardware.kvmModule == "kvm-intel";
          assert previewCfg.hardware.nvidia.prime.offload.enable;
          assert hmCfg.ember.desktop.ignoreDrmDevice != null;
          pkgs.runCommand "ember-hardware-profiles" { } ''
            # Instantiating both toplevels must not evaluate host-specific
            # policy into the shared closure.
            printf '%s\n%s\n' "${previewToplevel.drvPath}" "${forgeToplevel.drvPath}" > $out
          '';
      };
    };
}
