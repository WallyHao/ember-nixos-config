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

    export HOME="$TMPDIR"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export XDG_CONFIG_HOME="$TMPDIR/config"

    mkdir -p tools/svgs/themes
    cp tools/svgs/nordzy-templates/Nordzy-cursors-template.svg \
      tools/svgs/themes/Nordzy-Emberlight.svg
    cp tools/svgs/nordzy-templates/Nordzy-cursors-spinner-template.svg \
      tools/svgs/themes/Nordzy-Emberlight-spinner.svg
    for svg in tools/svgs/themes/Nordzy-Emberlight.svg tools/svgs/themes/Nordzy-Emberlight-spinner.svg; do
      sed -i \
        -e 's/#000000/#120b13/g' \
        -e 's/#ffffff/#b85753/g' \
        -e 's/#8fbcbb/#b85753/g' \
        -e 's/#00ff00/#8aa073/g' \
        -e 's/#ff0000/#b85753/g' \
        -e 's/#800080/#ae90c0/g' \
        -e 's/#ff7f2a/#c08366/g' "$svg"
    done

    # Render synchronously: the upstream wrapper races make.sh against PNG output.
    ( cd tools && python3 render-pngs.py svgs/themes/Nordzy-Emberlight.svg )
    ( cd tools && python3 render-pngs.py svgs/themes/Nordzy-Emberlight-spinner.svg )
    ( cd tools && bash make.sh Nordzy-Emberlight )

    test -s tools/pngs/24/left_ptr.png
    test -s tools/Nordzy-Emberlight/cursors/left_ptr
    if find tools/Nordzy-Emberlight/cursors -type f -empty | grep -q .; then
      echo "empty Xcursor files were generated" >&2
      find tools/Nordzy-Emberlight/cursors -type f -empty >&2
      exit 1
    fi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -d "$out/share/icons"
    cp -a tools/Nordzy-Emberlight "$out/share/icons/"
    runHook postInstall
  '';

  meta = {
    description = "Nordzy cursor theme recoloured with the Emberlight palette";
    homepage = "https://github.com/guillaumeboehm/Nordzy-cursors";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = pkgs.lib.platforms.linux;
  };
})
