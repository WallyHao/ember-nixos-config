{
  inputs,
  pkgs,
  inventory,
}:
let
  initialPassword = pkgs.writeText "ember-test-initial-password" "kl;'";
  newPassword = pkgs.writeText "ember-test-new-password" "ember-test-pass";
  wrongPassword = pkgs.writeText "ember-test-wrong-password" "definitely-not-the-password";

  # All positive/negative cases use the same probe. Its marker must be the
  # output of an authenticated command, never an echo of typed input.
  loginProbe =
    password: outcome: program: timeout:
    pkgs.writeShellScript "ember-login-${outcome}" ''
      exec ${pkgs.expect}/bin/expect ${./login.exp} ${password} ${outcome} ${program} ${toString timeout}
    '';
  realLogin = password: outcome: loginProbe password outcome "/run/current-system/sw/bin/login" 20;
  loginOk = realLogin initialPassword "accept";
  loginNew = realLogin newPassword "accept";
  loginOldShouldFail = realLogin initialPassword "reject";
  loginWrongPassword = realLogin wrongPassword "accept";
  loginWrongShouldFail = realLogin wrongPassword "reject";

  # These test-only programs exercise the exact success probe's timeout, EOF,
  # and input-echo paths. None authenticates or runs a shell command.
  noPrompt = pkgs.writeShellScript "ember-no-prompt" "sleep 5";
  earlyEof = pkgs.writeShellScript "ember-early-eof" "exit 0";
  echoOnly = pkgs.writeShellScript "ember-input-echo-only" ''
    printf 'Password:'
    IFS= read -r ignored
    printf '\n$ '
    IFS= read -r command
    printf '%s\n' "$command"
    sleep 5
  '';
  missingPrompt = loginProbe initialPassword "accept" noPrompt 2;
  unexpectedEof = loginProbe initialPassword "accept" earlyEof 2;
  missingMarker = loginProbe initialPassword "accept" echoOnly 2;

  changePassword = pkgs.writeText "ember-change-password.exp" ''
    set timeout 60
    proc fail {message} {
      puts stderr "FAIL: $message"
      exit 1
    }
    spawn login wallyhao
    expect {
      "Password:" {}
      timeout { fail "change-password login prompt timeout" }
      eof { fail "login exited before change-password prompt" }
    }
    send -- "kl;'\r"
    expect {
      -re {[$%#] } {}
      timeout { fail "change-password shell prompt timeout" }
      eof { fail "login exited before change-password shell prompt" }
    }
    send -- {printf 'EMBER_%s:%s\n' CHANGE "$(id -un)"}
    send -- "\r"
    expect {
      -re {(?n)^EMBER_CHANGE:wallyhao\r?$} {}
      timeout { fail "change-password initial login marker timeout" }
      eof { fail "login exited before change-password initial login" }
    }

    send -- "export LC_ALL=C; passwd\r"
    expect {
      -re {[Cc]urrent.*[Pp]assword:} {}
      timeout { fail "passwd current-password prompt timeout" }
      eof { fail "passwd exited before current-password prompt" }
    }
    send -- "kl;'\r"
    expect {
      -re {[Nn]ew.*[Pp]assword:} {}
      timeout { fail "passwd new-password prompt timeout" }
      eof { fail "passwd exited before new-password prompt" }
    }
    send -- "ember-test-pass\r"
    expect {
      -re {[Rr]etype new.*[Pp]assword:} {}
      timeout { fail "passwd retype-password prompt timeout" }
      eof { fail "passwd exited before retype-password prompt" }
    }
    send -- "ember-test-pass\r"
    expect {
      -re "password updated successfully" {}
      timeout { fail "passwd success message timeout" }
      eof { fail "passwd exited without a success message" }
    }
    expect {
      -re {[$%#] $} {}
      timeout { fail "shell prompt after passwd timeout" }
      eof { fail "shell exited after passwd" }
    }
    send -- {printf 'EMBER_%s:%s\n' CHANGED "$(id -un)"}
    send -- "\r"
    expect {
      -re {(?n)^EMBER_CHANGED:wallyhao\r?$} {}
      timeout { fail "post-passwd shell marker timeout" }
      eof { fail "shell exited before post-passwd marker" }
    }
    send -- "exit\r"
    expect {
      eof {}
      timeout { fail "post-passwd shell did not exit" }
    }
    exit 0
  '';

  extraTestScript = ''
    machine.wait_for_unit("multi-user.target")

    def assert_password_state(expected_hash):
        machine.succeed("test -L /etc/shadow")
        t.assertEqual(machine.succeed("readlink -f /etc/shadow").strip(), "/var/lib/nixos/shadow")
        t.assertEqual(machine.succeed("getent shadow wallyhao | cut -d: -f2").strip(), expected_hash)
        entries = machine.succeed("grep '^wallyhao:' /var/lib/nixos/shadow").splitlines()
        t.assertEqual(len(entries), 1)
        t.assertEqual(entries[0].split(":")[1], expected_hash)
        machine.succeed("passwd -S root | grep -q '^root L'")
        owner, mode = machine.succeed("stat -c '%u %a' /var/lib/nixos/shadow").split()
        t.assertEqual(owner, "0")
        t.assertEqual(int(mode, 8) & 0o077, 0, "shadow must not be accessible to group/others")

    def assert_probe_failure(command, reason):
        status, output = machine.execute("env LC_ALL=C " + command + " 2>&1")
        t.assertEqual(status, 1, output)
        t.assertIn("FAIL: " + reason, output)

    with subtest("account and TTY basics"):
        machine.wait_for_unit("greetd.service", timeout=180)
        machine.succeed("systemctl is-active greetd.service")
        machine.succeed("systemctl is-active getty@tty2.service")
        machine.succeed("test \"$(id -u wallyhao)\" = 1000")
        machine.succeed("test \"$(getent passwd wallyhao | cut -d: -f6)\" = /home/wallyhao")
        machine.succeed("getent passwd wallyhao | cut -d: -f7 | grep -q 'zsh$'")
        machine.succeed("test -L /etc/shadow")
        machine.succeed("readlink -f /etc/shadow | grep -q /var/lib/nixos/shadow")
        machine.succeed("passwd -S root | grep -q '^root L'")

    with subtest("same login probe rejects timeout, EOF, input echo, and wrong outcomes"):
        assert_probe_failure("${missingPrompt}", "password prompt timeout")
        assert_probe_failure("${unexpectedEof}", "login exited before password prompt")
        assert_probe_failure("${missingMarker}", "authenticated identity marker timeout")
        assert_probe_failure("${loginWrongPassword}", "password was rejected")

    with subtest("initial four-character password works on a real login pty"):
        machine.succeed("env LC_ALL=C ${loginOk}")

    with subtest("sudo authenticates the account password"):
        machine.succeed("printf '%s\\n' \"kl;'\" | runuser -u wallyhao -- env HOME=/home/wallyhao sudo -k -S -p ':' true")
        machine.fail("printf '%s\\n' 'wrong-password' | runuser -u wallyhao -- env HOME=/home/wallyhao sudo -k -S -p ':' true")

    with subtest("change the password as the user"):
        machine.succeed("env LC_ALL=C expect ${changePassword}")
        new_hash = machine.succeed("getent shadow wallyhao | cut -d: -f2").strip()
        t.assertNotEqual(new_hash, "${inventory.users.wallyhao.initialHashedPassword}")
        t.assertTrue(new_hash.startswith("$"), "passwd must create a non-empty crypt hash")
        assert_password_state(new_hash)

    with subtest("new password is effective immediately and old password is rejected"):
        machine.succeed("printf '%s\\n' 'ember-test-pass' | runuser -u wallyhao -- env HOME=/home/wallyhao sudo -k -S -p ':' true")
        machine.fail("printf '%s\\n' \"kl;'\" | runuser -u wallyhao -- env HOME=/home/wallyhao sudo -k -S -p ':' true")
        machine.succeed("env LC_ALL=C ${loginNew}")
        machine.succeed("env LC_ALL=C ${loginWrongShouldFail}")
        machine.succeed("env LC_ALL=C ${loginOldShouldFail}")

        machine.succeed("systemctl restart userborn.service")
        machine.wait_for_unit("userborn.service")
        assert_password_state(new_hash)
        machine.succeed("env LC_ALL=C ${loginNew}")
        machine.succeed("env LC_ALL=C ${loginOldShouldFail}")

    machine.reboot()
    machine.wait_for_unit("multi-user.target")
    assert_no_ordering_cycles()

    with subtest("password change survives first reboot and userborn re-activation"):
        assert_password_state(new_hash)
        machine.succeed("systemctl restart userborn.service")
        machine.wait_for_unit("userborn.service")
        assert_password_state(new_hash)
        machine.succeed("env LC_ALL=C ${loginOldShouldFail}")
        machine.succeed("env LC_ALL=C ${loginNew}")
        machine.succeed("printf '%s\\n' 'ember-test-pass' | runuser -u wallyhao -- env HOME=/home/wallyhao sudo -k -S -p ':' true")

    machine.reboot()
    machine.wait_for_unit("multi-user.target")
    assert_no_ordering_cycles()

    with subtest("password change survives second reboot and userborn re-activation"):
        assert_password_state(new_hash)
        machine.succeed("env LC_ALL=C ${loginOldShouldFail}")
        machine.succeed("env LC_ALL=C ${loginNew}")
        machine.succeed("systemctl restart userborn.service")
        machine.wait_for_unit("userborn.service")
        assert_password_state(new_hash)
        machine.succeed("env LC_ALL=C ${loginOldShouldFail}")
        machine.succeed("env LC_ALL=C ${loginNew}")

    machine.shutdown()
  '';
in
import ./common.nix {
  inherit
    inputs
    pkgs
    inventory
    ;
  name = "ember-vm-accounts";
  inherit extraTestScript;
  extraSystemConfig =
    {
      lib,
      ...
    }:
    {
      # The account probe must not depend on the user's p10k theme. Keep the
      # target login shell, but use the account-test-only fixed prompt.
      home-manager.users.wallyhao = {
        programs.zsh.enable = lib.mkForce false;
        home.file.".zshrc".text = "PROMPT='$ '\n";
      };
    };
}
