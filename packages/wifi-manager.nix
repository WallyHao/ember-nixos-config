{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  glib,
  wrapGAppsHook4,
  gtk4,
  gtk4-layer-shell,
  libpulseaudio,
  libxkbcommon,
  wayland,
}:

rustPlatform.buildRustPackage {
  pname = "wifi-manager";
  version = "0.4.0-unstable-2026-10-30";

  src = fetchFromGitHub {
    owner = "Vijay-papanaboina";
    repo = "wifi-manager";
    rev = "a4ec32e98b98e5d0cc25b9a3cc79be49457ee78e";
    hash = "sha256-GLbLakIEdkV9gRHCtJd2AMByujTyVeDi1ZF7IMHxZ0s=";
  };

  cargoHash = "sha256-7/4iqf7LGMuv8FJv86APoy9fXsTSbi+7CBXc0KkinQU=";
  patches = [
    ./wifi-manager/compact-panel.patch
    ./wifi-manager/roomier-panel.patch
    ./wifi-manager/gtk-audio-compat.patch
    ./wifi-manager/ember-panel-services.patch
  ];

  strictDeps = true;
  nativeBuildInputs = [
    pkg-config
    glib
    wrapGAppsHook4
  ];
  buildInputs = [
    gtk4
    gtk4-layer-shell
    libpulseaudio
    libxkbcommon
    wayland
  ];

  # The desktop integration check exercises the packaged app.
  doCheck = false;

  meta = {
    description = "GTK quick settings panel for Wayland";
    homepage = "https://github.com/Vijay-papanaboina/wifi-manager";
    license = lib.licenses.mit;
    mainProgram = "wifi-manager";
    platforms = lib.platforms.linux;
  };
}
