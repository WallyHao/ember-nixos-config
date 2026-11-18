{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt;

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          nixfmt
          nix-output-monitor
          nix-eval-jobs
          nixos-facter
          shellcheck
          actionlint
          deadnix
          ripgrep
          jq
          gitleaks
          python3
          pciutils
          usbutils
          whois
          util-linux
        ];
      };
    };
}
