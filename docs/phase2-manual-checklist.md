# Phase 2 manual checklist

This list is for the future installed system. Nothing in phase 2 installs or
activates the host; VM results are separate from physical hardware results.

## First login

1. At the Hearth greeter, enter `wallyhao` and the phase-1 initial password.
   Change it with `passwd` immediately.
2. Confirm `Super+Return` opens Foot.
3. Install the base user profile as `wallyhao` (no sudo):

   ```sh
   cd /path/to/hearth-nixos-config
   nix profile install --no-update-lock-file \
     --profile "$HOME/.local/state/nix/profiles/profile" \
     'path:./software#base'
   ```

4. In a new Foot window, check:

   ```sh
   git --version
   yazi --version
   eza --version
   ```

5. Run `y` in a directory, select another directory in Yazi, quit, and confirm
   the parent shell changed directory. Cancel once and confirm it did not.
6. Open `Super+D` and start Foot; `Super+V` for clipboard history; `Super+C`
   or `Super+P` for the control center.
7. Open the session panel with `Super+Shift+R` / `Super+Shift+T`; cancel and
   verify the session is still running before testing a real reboot.

## Keyring and history

1. After login, create a test login-keyring item with Seahorse if available,
   or another Secret Service client. Do not store real credentials in logs.
2. Reboot and log in again; confirm the keyring is unlocked by the login
   password and the item is readable.
3. Copy test text, close the source application, open Noctalia clipboard
   history, and confirm the test text remains. Reboot and read it back.
4. Change the account password with `passwd`, log out/in, and check that the
   keyring still unlocks. If it does not, do not delete the keyring; unlock it
   with its previous password, then change its password to the current account
   password and record the limitation. Do not use an empty keyring password.

## Hardware and appearance

- The real-machine preparation follow-up adds Fcitx5/Rime Ice. In Foot,
  use Ctrl+Space, type nihao and commit with Space; check candidates and
  switching back to English. See [setup and usage](real-machine-preparation.md)
  for network, proxy and oh-my-pi provisioning before physical validation.
- Verify volume and brightness keys on the real laptop; the VM has no battery
  or backlight. TLP remains the only power policy owner.
- Check Niri output detection, scaling, refresh rate, and multi-monitor
  behavior. No fixed output name, resolution, scale, or GPU path is in the
  managed config.
- Check Intel rendering and NVIDIA PRIME offload only when explicitly needed.
  Do not make `nvidia-offload` the default Niri/Noctalia/Foot command.
- Check suspend/lid behavior. Phase 2 does not add an automatic lock/idle
  policy and does not claim suspend is hibernation.
- Verify Foot font rendering and the fallback. The locked package provides
  `LXGW WenKai Mono`, not the old `LXGW WenKai Mono GB` family name.

## Recovery

- If the graphical session fails, switch to tty2 and use the normal password
  login. `getty@tty2` is intentionally kept password-protected.
- From tty2, inspect:

  ```sh
  systemctl status greetd
  systemctl --user status niri noctalia
  journalctl -b -u greetd
  journalctl --user -b
  ```

- Do not pass a host disk to QEMU while diagnosing, and do not run activation,
  installation, or firmware commands from the USB host.
