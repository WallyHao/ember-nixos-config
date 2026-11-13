{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { system, pkgs, ... }:
    let
      inventory = import ../inventory;
      deployment = import ../lib/deployment.nix {
        inherit inventory;
      };
      host =
        (import ../lib/eval-inventory.nix {
          lib = inputs.nixpkgs.lib;
          inherit inventory;
        }).hosts.ember;

      preview = (import ../lib/mk-host.nix) {
        inherit inputs inventory;
        hostName = "ember";
        hardwareModule = host.physicalHardwareModule;
        storageModule = ../tests/fixtures/storage.nix;
      };

      previewToplevel = preview.system.config.system.build.toplevel;
      previewCfg = preview.system.config;
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
      userEvalResults = import ../tests/eval/user-environment.nix {
        inherit
          inputs
          inventory
          deployment
          ;
      };
      userEvalJson = builtins.toJSON userEvalResults;

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
      packages.migration-tool = pkgs.writeShellApplication {
        name = "ember-migrate-folio-data";
        runtimeInputs = [ pkgs.util-linux ];
        text = ''
          exec ${
            pkgs.python3.withPackages (ps: [ ps.pyyaml ])
          }/bin/python3 ${../scripts/migrate-folio-data.py} --normalizer ${../modules/nixos/proxy-data.py} "$@"
        '';
      };

      checks = {
        system-preview = previewToplevel;

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

        eval-user-environment = pkgs.runCommand "ember-eval-user-environment" { } ''
          printf '%s\n' '${userEvalJson}' > $out
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
              test -s ${hmCfg.xdg.configFile."fuzzel/fuzzel.ini".source}
              test -s ${hmCfg.xdg.configFile."waybar/config".source}
              test -s ${hmCfg.xdg.configFile."mako/config".source}
              zsh -n ${../modules/home/terminal/resources/p10k.zsh}
              zsh -n ${hmCfg.home.file."./.zshrc".source}
              nvim --headless -u ${nixvimInit} -c 'set number?' -c 'qa!' 2>&1 | grep -q 'number'
              touch $out
            '';

        vm-accounts = import ../tests/vm/accounts.nix vmArgs;
        vm-persistence = import ../tests/vm/persistence.nix vmArgs;
        vm-offline-boot = import ../tests/vm/offline-boot.nix vmArgs;
        vm-offline-desktop = import ../tests/vm/offline-desktop.nix vmArgs;
        vm-offline-link = import ../tests/vm/offline-link.nix vmArgs;
        vm-desktop = import ../tests/vm/desktop.nix vmArgs;
        vm-user-environment = import ../tests/vm/user-environment.nix vmArgs;
        vm-connectivity = import ../tests/vm/connectivity.nix vmArgs;
      };
    };
}
