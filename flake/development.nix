{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          nixfmt-rfc-style
          shellcheck
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
