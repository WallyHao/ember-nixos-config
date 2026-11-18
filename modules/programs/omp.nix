{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;

  theme = {
    name = "emberlight";
    vars = {
      fg = c.base05;
      bright = c.base06;
      muted = c.base04;
      dim = c.base03;
      accent = c.base0D;
      green = c.base0B;
      red = c.base08;
      yellow = c.base0A;
      purple = c.base0E;
      panel = c.base01;
      selected = c.base02;
      border = c.base03;
    };
    colors = {
      accent = "accent";
      border = "border";
      borderAccent = "accent";
      borderMuted = "border";
      success = "green";
      error = "red";
      warning = "yellow";
      muted = "muted";
      dim = "dim";
      text = "fg";
      thinkingText = "muted";

      selectedBg = "selected";
      userMessageBg = "panel";
      customMessageBg = "panel";
      toolPendingBg = "panel";
      toolSuccessBg = "panel";
      toolErrorBg = "panel";
      statusLineBg = "panel";

      userMessageText = "fg";
      customMessageText = "fg";
      customMessageLabel = "accent";
      toolTitle = "fg";
      toolOutput = "muted";

      mdHeading = "accent";
      mdLink = "accent";
      mdLinkUrl = "muted";
      mdCode = "yellow";
      mdCodeBlock = "fg";
      mdCodeBlockBorder = "border";
      mdQuote = "muted";
      mdQuoteBorder = "border";
      mdHr = "border";
      mdListBullet = "accent";

      toolDiffAdded = "green";
      toolDiffRemoved = "red";
      toolDiffContext = "muted";

      syntaxComment = "muted";
      syntaxKeyword = "purple";
      syntaxFunction = "accent";
      syntaxVariable = "fg";
      syntaxString = "green";
      syntaxNumber = "yellow";
      syntaxType = "accent";
      syntaxOperator = "red";
      syntaxPunctuation = "muted";

      thinkingOff = "dim";
      thinkingMinimal = "muted";
      thinkingLow = "accent";
      thinkingMedium = "green";
      thinkingHigh = "yellow";
      thinkingXhigh = "purple";
      bashMode = "green";
      pythonMode = "yellow";

      statusLineSep = "dim";
      statusLineModel = "purple";
      statusLinePath = "accent";
      statusLineGitClean = "green";
      statusLineGitDirty = "yellow";
      statusLineContext = "accent";
      statusLineSpend = "muted";
      statusLineStaged = "green";
      statusLineDirty = "yellow";
      statusLineUntracked = "red";
      statusLineOutput = "fg";
      statusLineCost = "yellow";
      statusLineSubagents = "purple";
    };
  };
in
{
  # OMP owns writable settings/auth/session files. Its binary belongs to the
  # independent software profile; never symlink its credentials into the store.
  home.activation.emberOmpState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/install -d -m 700 "$HOME/.omp" "$HOME/.omp/agent"
  '';

  # The palette is a managed file; the selected theme name lives in OMP's
  # writable config, so activation updates just that key and preserves the rest.
  home.file.".omp/agent/themes/emberlight.json".text = builtins.toJSON theme;

  home.activation.emberOmpTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ompConfig="$HOME/.omp/agent/config.yml"
    ${pkgs.coreutils}/bin/install -d -m 700 "$HOME/.omp/agent"
    if [ ! -e "$ompConfig" ]; then
      umask 077
      printf 'theme:\n  dark: emberlight\n' > "$ompConfig"
    elif [ "$(${pkgs.yq-go}/bin/yq -r '.theme.dark // ""' "$ompConfig" 2>/dev/null || true)" != "emberlight" ]; then
      ${pkgs.yq-go}/bin/yq -i '.theme.dark = "emberlight"' "$ompConfig" ||
        echo "warning: could not select the emberlight OMP theme in $ompConfig" >&2
    fi
  '';

  # OMP discovers every skill as <root>/<name>/SKILL.md at startup. Keep the
  # Documents skills root registered in the writable config without dropping
  # other custom roots the user adds at runtime.
  home.activation.emberOmpSkills = lib.hm.dag.entryAfter [ "emberOmpTheme" ] ''
    ompConfig="$HOME/.omp/agent/config.yml"
    skillsDir="$HOME/Documents/skills"
    ${pkgs.yq-go}/bin/yq -i \
      ".skills.customDirectories = (((.skills.customDirectories // []) + [\"$skillsDir\"]) | unique)" \
      "$ompConfig" ||
      echo "warning: could not register $skillsDir in $ompConfig" >&2
  '';
}
