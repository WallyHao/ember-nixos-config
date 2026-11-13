{
  inputs,
  pkgs,
  inventory,
}:
let
  softwareBase = (import ../../software/packages.nix { inherit pkgs; }).workstation;
  profileHelper = pkgs.runCommand "ember-profile-helper-fixture" { } ''
    mkdir -p $out/scripts
    cp ${../../scripts/ember} $out/scripts/ember
    cp ${../../scripts/hearth} $out/scripts/hearth
    cp -r ${../../software} $out/software
    cp ${../../justfile} $out/justfile
  '';
  profilePath = "/home/wallyhao/.local/state/nix/profiles/profile";

  extraTestScript = ''
    import re

    profilePath = "${profilePath}"

    user_env = (
        "runuser -u wallyhao -- env "
        "NO_COLOR=1 "
        "HOME=/home/wallyhao "
        "USER=wallyhao "
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/wallyhao/bin "
        "XDG_RUNTIME_DIR=/run/user/1000"
    )

    def as_user(command):
        return machine.succeed(f"{user_env} sh -c {shlex.quote(command)}")

    machine.wait_for_unit("multi-user.target", timeout=180)
    machine.wait_for_unit("home-manager-wallyhao.service", timeout=180)

    with subtest("Home Manager activation is managed by the system and idempotent"):
        machine.succeed("test -f /home/wallyhao/.zshrc")
        before = machine.succeed("sha256sum /home/wallyhao/.zshrc").split()[0]
        machine.succeed("systemctl restart home-manager-wallyhao.service")
        machine.wait_for_unit("home-manager-wallyhao.service", timeout=180)
        after = machine.succeed("sha256sum /home/wallyhao/.zshrc").split()[0]
        t.assertEqual(before, after)
        machine.succeed("test -f /home/wallyhao/.config/niri/config.kdl")
        machine.succeed("test -f /home/wallyhao/.config/foot/foot.ini")
        machine.succeed("test -f /home/wallyhao/.config/waybar/config")
        machine.succeed("test -f /home/wallyhao/.config/fuzzel/fuzzel.ini")
        machine.succeed("test -f /home/wallyhao/.config/yazi/yazi.toml")

    with subtest("state directories are private before first use"):
        for path in [
            "/home/wallyhao/.local/state/zsh",
            "/home/wallyhao/.local/share/keyrings",
            "/home/wallyhao/.local/state/nvim/undo",
            "/home/wallyhao/.config/fcitx5",
            "/home/wallyhao/.local/share/fcitx5",
            "/home/wallyhao/.omp",
        ]:
            t.assertEqual(
                machine.succeed(f"stat -c '%U %a' {path}").strip(),
                "wallyhao 700",
            )

    with subtest("Zsh loads the managed prompt, history, aliases and y"):
        as_user("zsh -n /home/wallyhao/.zshrc")
        shell_state = as_user(
            "zsh -lic 'print -r -- \"P10K=$POWERLEVEL9K_MODE\"; "
            "print -r -- \"DIRCOLOR=$POWERLEVEL9K_DIR_FOREGROUND\"; "
            "print -r -- \"ELEMENTS=''${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[*]}\"; "
            "print -r -- \"HIST=$HISTFILE\"; "
            "whence -w y; whence -w compinit; whence -w fzf-tab-complete || true'"
        )
        t.assertIn("P10K=nerdfont-complete", shell_state)
        t.assertIn("DIRCOLOR=#dcc9d2", shell_state)
        t.assertIn("command_execution_time", shell_state)
        t.assertIn("prompt_char", shell_state)
        t.assertIn("HIST=/home/wallyhao/.local/state/zsh/history", shell_state)
        t.assertIn("y: function", shell_state)
        t.assertIn("compinit: function", shell_state)
        # The profile is not installed yet, so fzf integration must be skipped
        # rather than failing shell startup.
        t.assertNotIn("fzf-tab-complete: function", shell_state)

    with subtest("Nixvim opens, changes and saves a file without network"):
        as_user("sh -c 'echo hello > /home/wallyhao/Documents/nvim-test.txt'")
        as_user(
            "timeout 30 nvim --headless /home/wallyhao/Documents/nvim-test.txt "
            "+'%s/hello/world/' +wq"
        )
        t.assertEqual(machine.succeed("cat /home/wallyhao/Documents/nvim-test.txt").strip(), "world")
        machine.succeed("runuser -u wallyhao -- test -x /etc/profiles/per-user/wallyhao/bin/nvim")
        machine.succeed("runuser -u wallyhao -- test -x /etc/profiles/per-user/wallyhao/bin/vi")
        machine.succeed("runuser -u wallyhao -- test -x /etc/profiles/per-user/wallyhao/bin/vim")

    with subtest("base profile is installed by the target user, not HM or root"):
        machine.fail("test -e ${profilePath}/bin/yazi")
        machine.succeed("findmnt /nix/store --types overlay")
        machine.succeed("test -d /nix/store/.links")
        machine.succeed("systemctl is-active nix-daemon.socket")
        as_user("command -v just")
        as_user("cd ${profileHelper}; just profile-install")
        first_generation = as_user("readlink ${profilePath}").strip()
        as_user("cd ${profileHelper}; just profile-install")
        t.assertEqual(as_user("readlink ${profilePath}").strip(), first_generation)
        t.assertEqual(
            machine.succeed(f"stat -c '%U' {profilePath}").strip(),
            "wallyhao",
        )
        as_user("${profilePath}/bin/git --version")
        as_user("${profilePath}/bin/yazi --version")
        as_user("${profilePath}/bin/eza --version")
        t.assertIn("18.18.6", as_user("${profilePath}/bin/omp --version"))
        t.assertIn("USAGE", as_user("${profilePath}/bin/omp --help"))
        as_user("printf 'startup:\\n  quiet: true\\n' > /home/wallyhao/.omp/agent/config.yml")

        shell_state = as_user(
            "zsh -lic 'command -v yazi; command -v git; command -v eza; "
            "print -r -- \"YFUNC=$(whence -w y)\"'"
        )
        t.assertIn("${profilePath}/bin/yazi", shell_state)
        t.assertIn("${profilePath}/bin/git", shell_state)
        t.assertIn("YFUNC=y: function", shell_state)

    with subtest("eza and fzf integrations activate once the profile exists"):
        shell_state = as_user(
            "zsh -lic 'whence -w ll; whence -w fzf-tab-complete; "
            "print -r -- \"EZA=''${EZA_COLORS%%:*}\"; "
            "print -r -- \"FZF=$FZF_DEFAULT_OPTS\"'"
        )
        t.assertIn("ll: function", shell_state)
        t.assertIn("fzf-tab-complete: function", shell_state)
        t.assertIn("EZA=reset", shell_state)
        t.assertIn("--height=45%", shell_state)

        as_user(
            "mkdir -p '/tmp/ember-eza/a/b' '/tmp/ember-eza/dir with space' "
            "&& touch /tmp/ember-eza/a/file"
        )
        one = as_user("zsh -lic 'cd /tmp/ember-eza && ll 1'")
        t.assertIn("a", one)
        t.assertNotIn("b", one)
        two = as_user("zsh -lic 'cd /tmp/ember-eza && ll 2'")
        t.assertIn("b", two)
        spaced = as_user("zsh -lic \"ll 2 '/tmp/ember-eza/dir with space'\"")
        t.assertIn("dir with space", spaced)

        colored = as_user(
            "env -u NO_COLOR TERM=xterm-256color script -qec \"zsh -lic 'cd /tmp/ember-eza && ll 2'\" /dev/null"
        )
        # base0D directory colour reaches a real pty through EZA_COLORS.
        t.assertIn("38;2;140;144;194", colored)

        canceled = as_user(
            "printf '\\033' | TERM=xterm-256color "
            "script -qec \"zsh -lic 'cd /tmp && fzf-cd-widget; print -r -- PWD=$PWD'\" /dev/null"
        )
        t.assertIn("PWD=/tmp", canceled)

    with subtest("independent desktop configs use Folio geometry and Emberlight"):
        config = machine.succeed("cat /home/wallyhao/.config/fcitx5/conf/classicui.conf")
        t.assertIn("Theme=emberlight", config)
        t.assertIn("Mono GB 18", config)
        theme = machine.succeed("cat /home/wallyhao/.local/share/fcitx5/themes/emberlight/theme.conf")
        t.assertIn("FullWidthHighlight=False", theme)
        t.assertIn("HighlightBackgroundColor=#00000000", theme)
        t.assertIn("max-history=0", machine.succeed("cat /home/wallyhao/.config/mako/config"))
        machine.succeed("test -f /home/wallyhao/.config/swaylock/config")
        machine.succeed("test ! -f /home/wallyhao/.config/noctalia/config.toml")

    with subtest("native profile history and rollback preserve the base"):
        # Create unrooted packages in the real guest store. Only the native
        # profile generations may keep the history fixture alive during GC.
        for name in ("history", "garbage"):
            as_user(
                f"sh -c \"mkdir -p /home/wallyhao/Downloads/ember-{name}/bin; "
                f"printf '#!/bin/sh\\necho ember-{name}\\n' "
                f"> /home/wallyhao/Downloads/ember-{name}/bin/ember-{name}; "
                f"chmod +x /home/wallyhao/Downloads/ember-{name}/bin/ember-{name}\""
            )
        historical = as_user("nix store add-path /home/wallyhao/Downloads/ember-history").strip()
        garbage = as_user("nix store add-path /home/wallyhao/Downloads/ember-garbage").strip()
        as_user(
            "nix profile install "
            f"--profile {profilePath} {historical}"
        )
        history = as_user(
            f"nix profile history --profile {profilePath}"
        )
        history = re.sub(r"\x1b\[[0-9;]*m", "", history)
        t.assertIn("Version 1", history)
        t.assertIn("Version 2", history)
        as_user("nix profile rollback --profile ${profilePath}")
        as_user(f"nix profile history --profile {profilePath}")
        machine.fail(f"test -e {profilePath}/bin/ember-history")
        as_user("${profilePath}/bin/yazi --version")
        as_user(f"{profilePath}-2-link/bin/ember-history")

    with subtest("guest GC retains native profile history and collects unrooted garbage"):
        machine.succeed("findmnt /nix/.ro-store -no OPTIONS | grep -w ro")
        machine.succeed("nix-store --gc")
        machine.fail(f"test -e {garbage}")
        as_user("${profilePath}/bin/yazi --version")
        t.assertEqual(as_user(f"{profilePath}-2-link/bin/ember-history").strip(), "ember-history")

    with subtest("Zsh history survives HM reactivation and reboot"):
        marker = "ember-history-marker"
        as_user(f"zsh -lic 'print -s -- {marker}; fc -AI'")
        machine.succeed(
            f"grep -q {marker} /home/wallyhao/.local/state/zsh/history"
        )
        machine.reboot()
        machine.wait_for_unit("multi-user.target", timeout=180)
        machine.wait_for_unit("home-manager-wallyhao.service", timeout=180)
        machine.succeed(
            f"grep -q {marker} /home/wallyhao/.local/state/zsh/history"
        )
        t.assertEqual(
            machine.succeed("stat -c '%U %a' /home/wallyhao/.local/state/zsh").strip(),
            "wallyhao 700",
        )
        as_user("${profilePath}/bin/yazi --version")
        as_user("${profilePath}-2-link/bin/ember-history")
        t.assertIn("18.18.6", as_user("${profilePath}/bin/omp --version"))
        as_user("grep -q 'quiet: true' /home/wallyhao/.omp/agent/config.yml")
        as_user(f"nix profile history --profile {profilePath}")
        as_user("timeout 30 nvim --headless /home/wallyhao/Documents/nvim-test.txt +undo +wq")
        t.assertEqual(machine.succeed("cat /home/wallyhao/Documents/nvim-test.txt").strip(), "hello")

    machine.shutdown()
  '';
in
import ./common.nix {
  inherit
    inputs
    pkgs
    inventory
    ;
  name = "ember-vm-user-environment";
  testTimeout = 1200;
  inherit extraTestScript;
  extraSystemConfig =
    {
      pkgs,
      ...
    }:
    {
      # Make the offline fixture available and registered without installing
      # its tools into the system PATH before the user's native profile step.
      system.extraDependencies = [
        softwareBase
        profileHelper
      ];
    };
}
