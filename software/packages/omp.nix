{
  lib,
  stdenvNoCC,
  stdenv,
  autoPatchelfHook,
  fetchurl,
  makeWrapper,
  bash,
  git,
  ripgrep,
  fd,
  cacert,
}:
stdenvNoCC.mkDerivation {
  pname = "oh-my-pi";
  version = "18.18.6";
  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v18.18.6/omp-linux-x64";
    hash = "sha256-qAWbld5eq6Cz+29xgoQtZh/q4pyykxzb66KYbbR1Hss=";
  };
  dontUnpack = true;
  dontStrip = true;
  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  installPhase = ''
    install -Dm755 "$src" "$out/libexec/omp"
    makeWrapper "$out/libexec/omp" "$out/bin/omp" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          git
          ripgrep
          fd
        ]
      } \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    "$out/bin/omp" --version | grep -F '18.18.6'
    "$out/bin/omp" --help > "$TMPDIR/omp-help"
    grep -i 'usage' "$TMPDIR/omp-help"
  '';
  meta = {
    description = "Oh My Pi terminal coding agent (pinned upstream standalone release)";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "omp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
