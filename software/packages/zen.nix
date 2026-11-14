{ pkgs }:
let
  # Reuse Folio's reviewed upstream pin, without its browser profile or extensions.
  upstream = builtins.fetchTree {
    type = "github";
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "a12d482485d877cc066516ea256b435b209a1a8c";
    narHash = "sha256-C9BpLH4dNggam12nz/Fx/M0Vlbw8WcT/cpOc37DPQAA=";
  };
in
(import (upstream.outPath + "/default.nix") { inherit pkgs; }).beta
