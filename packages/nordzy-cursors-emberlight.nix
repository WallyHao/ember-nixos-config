# Nordzy cursor theme regenerated with the Emberlight palette.
{ pkgs }:
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "nordzy-cursors-emberlight";
  version = "0-unstable-2026-11-13";

  src = pkgs.fetchzip {
    url = "https://github.com/guillaumeboehm/Nordzy-cursors/archive/c7fc485e9e4fd974c4f4ff9f5f14610fa7835e7b.tar.gz";
    hash = "sha256-0586kd78VRi8ymYo0r6TEu4ZWu4/p9usj5j8rKanE8U=";
  };

  # The generator writes its SVG/PNG intermediates into the source tree.
  dontUnpack = true;

  nativeBuildInputs = [
    pkgs.inkscape
    pkgs.python3
    pkgs.xcursorgen
    pkgs.bash
    pkgs.coreutils
    pkgs.gnused
  ];

  buildPhase = ''
    runHook preBuild

    cp -a ${finalAttrs.src}/. .
    chmod -R u+w .

    # render-pngs.py invokes `python`; provide a python3-backed shim.
    mkdir -p bin
    cat > bin/python <<EOF
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.python3}/bin/python3 "$@"
    EOF
    chmod +x bin/python
    export PATH="$PWD/bin:$PATH"

    export HOME="$TMPDIR"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export XDG_CONFIG_HOME="$TMPDIR/config"

    # The generator moves the theme under xcursors/; create it explicitly.
    mkdir -p xcursors
    bash tools/custom_theme.sh \
      -n Nordzy-Emberlight \
      -f '#120b13' \
      -b '#dcc9d2' \
      -a '#b85753' \
      -g '#8aa073' \
      -r '#b85753' \
      -p '#ae90c0' \
      -o '#edd5a2'

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -d "$out/share/icons"
    cp -a xcursors/Nordzy-Emberlight "$out/share/icons/"
    runHook postInstall
  '';

  meta = {
    description = "Nordzy cursor theme recoloured with the Emberlight palette";
    homepage = "https://github.com/guillaumeboehm/Nordzy-cursors";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = pkgs.lib.platforms.linux;
  };
})
