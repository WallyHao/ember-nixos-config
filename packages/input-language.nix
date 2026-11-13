# Standalone observer adapted from Folio; no manager/runtime framework dependency.
{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "ember-input-language";
  version = "0.1.0";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [
    pkgs.glib
    pkgs.jansson
  ];
  buildPhase = ''
    $CC -std=c11 -Wall -Wextra -Werror -O2 ${../modules/home/desktop/resources/input-language.c} \
      $(pkg-config --cflags --libs gio-2.0 gio-unix-2.0 jansson) -o ember-input-language
  '';
  installPhase = "mkdir -p $out/bin; cp ember-input-language $out/bin/";
}
