{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchYarnDeps,
  nodejs,
  yarnConfigHook,
  yarnBuildHook,
  electron-bin,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  writeText,
  colors,
  polarity,
}:
let
  desktopId = "io.github.realkai42.QwertyLearner";
  rev = "8482c3874b12cedfd6ead83917698d9b81708d93";
  theme = writeText "qwerty-learner-ember-theme.json" (builtins.toJSON { inherit colors polarity; });
  useNpmRegistry = ''
    substituteInPlace yarn.lock \
      --replace-fail 'https://registry.npmmirror.com/' 'https://registry.npmjs.org/'
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "qwerty-learner";
  version = "0.1.0-unstable-2026-11-23";

  src = fetchFromGitHub {
    owner = "RealKai42";
    repo = "qwerty-learner";
    inherit rev;
    hash = "sha256-WooS+3elqr8K70sgXMPez2CPvqcSjE7dtaiOeKMJqPo=";
  };

  yarnOfflineCache = fetchYarnDeps {
    name = "${finalAttrs.pname}-yarn-deps";
    inherit (finalAttrs) src;
    postPatch = useNpmRegistry;
    hash = "sha256-hxFBu/dcIhPH8jC/Va7y8MxBDWoZwTmKN/6XUT0EQEg=";
  };

  patches = [ ./qwerty-learner/button-contrast.patch ];

  postPatch = useNpmRegistry + ''
    substituteInPlace package.json --replace-fail 'vite build --base=./' 'vite build --base=/'
    # The GitHub source archive has no Git metadata for Vite to query.
    substituteInPlace vite.config.ts \
      --replace-fail "import { getLastCommit } from 'git-last-commit'" "" \
      --replace-fail \
        $'await new Promise<string>((resolve) => {\n    return getLastCommit((err, commit) => (err ? \'unknown\' : resolve(commit.shortHash)))\n  })' \
        "'${builtins.substring 0 8 rev}'"

    cp ${theme} ember-theme.json
    cp ${./qwerty-learner/ember-tailwind.cjs} ember-tailwind.cjs
    substituteInPlace tailwind.config.js \
      --replace-fail 'module.exports = {' $'module.exports = {\n  presets: [require("./ember-tailwind.cjs")],' \
      --replace-fail $'      colors: {\n        primary: \'#6366f1\',\n      },\n' ""

    substituteInPlace index.html \
      --replace-fail "('state' in localStorage && JSON.parse(localStorage.state).darkMode) ||" \
        "localStorage.getItem('isOpenDarkModeAtom') === 'true' ||" \
      --replace-fail "!('state' in localStorage)" "localStorage.getItem('isOpenDarkModeAtom') !== 'false'" \
      --replace-fail '#818CF8' '${colors.base0F}'
    substituteInPlace src/index.css \
      --replace-fail 'background-color: #faf9ff;' 'background-color: var(--ember-background);' \
      --replace-fail 'color: #000;' 'color: var(--ember-foreground);' \
      --replace-fail 'rgba(50, 46, 129,' 'rgba(var(--ember-shadow),' \
      --replace-fail '#f66, #f90' '${colors.base08}, ${colors.base0A}' \
      --replace-fail 'animation: gradient-text-hue 5s linear infinite;' "" \
      --replace-fail $'@keyframes gradient-text-hue {\n  from {\n    filter: hue-rotate(0);\n  }\n  to {\n    filter: hue-rotate(-1turn);\n  }\n}\n\n' "" \
      --replace-fail 'border-color: #f0f0f0;' 'border-color: var(--ember-foreground);'
    substituteInPlace src/components/Loading/index.tsx \
      --replace-fail 'bg-[#faf9ff;]' 'bg-[var(--ember-background)]'
    substituteInPlace src/pages/Typing/components/WordPanel/components/Word/Notation.tsx \
      --replace-fail 'text-gray-800 dark:text-opacity-80' 'text-gray-800 dark:text-gray-100 dark:text-opacity-80'
    substituteInPlace src/pages/Typing/components/Progress/index.tsx \
      --replace-fail 'dark:bg-indigo-200' 'dark:bg-gray-700'
    substituteInPlace src/pages/Typing/components/ResultScreen/index.module.css \
      --replace-fail '#818cf8' 'var(--ember-highlight)'
    substituteInPlace src/pages/Typing/components/Setting/index.module.css \
      --replace-fail '#e5e5e5' '${colors.base05}' \
      --replace-fail '#525252' '${colors.base03}' \
      --replace-fail '#374151' '${colors.base02}' \
      --replace-fail '#d4d4d8' '${colors.base04}' \
      --replace-fail '#fff' '${colors.base07}' \
      --replace-fail '#1f2937' '${colors.base01}'

    substituteInPlace src/pages/Analysis/components/{HeatmapCharts,KeyboardWithBarCharts}.tsx \
      --replace-fail '#fff' '${colors.base06}' --replace-fail '#000' '${colors.base02}' \
      --replace-fail 'hsl(0, 0%, 22%)' '${colors.base02}' --replace-fail '#f0f0f0' '${colors.base06}' \
      --replace-fail '#818cf8' '${colors.base0A}' --replace-fail '#6366f1' '${colors.base0F}'
    substituteInPlace src/pages/Analysis/components/LineCharts.tsx \
      --replace-fail '    const option = {' \
        "    const option = { color: [isOpenDarkMode ? '${colors.base0A}' : '${colors.base0F}'],"
  '';

  nativeBuildInputs = [
    nodejs
    yarnConfigHook
    yarnBuildHook
    makeWrapper
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = desktopId;
      desktopName = "Qwerty Learner";
      exec = finalAttrs.pname;
      icon = finalAttrs.pname;
      startupWMClass = desktopId;
      categories = [ "Education" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/qwerty-learner"
    cp -r build "$out/share/qwerty-learner/site"
    install -m644 ${./qwerty-learner/main.cjs} "$out/share/qwerty-learner/main.cjs"
    install -m644 ${theme} "$out/share/qwerty-learner/ember-theme.json"
    install -Dm644 public/android-chrome-192x192.png \
      "$out/share/icons/hicolor/192x192/apps/qwerty-learner.png"
    makeWrapper ${lib.getExe electron-bin} "$out/bin/qwerty-learner" \
      --add-flags "$out/share/qwerty-learner/main.cjs"

    runHook postInstall
  '';

  meta = {
    description = "Typing practice and vocabulary learning";
    homepage = "https://github.com/RealKai42/qwerty-learner";
    license = lib.licenses.gpl3Only;
    mainProgram = "qwerty-learner";
    platforms = lib.platforms.linux;
  };
})
