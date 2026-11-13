# Ember implementation instructions

Current plan: `../plan/04-ember-emberlight-desktop-migration.md`. Read current
`docs/phase4-status.md` and `docs/phase4-migration.md` before changing deployment
or state handling. Older phase reports are historical evidence, not current status.

## Current ownership

- Canonical config/hostname/options: Ember / ember / ember.*. User remains
  wallyhao, UID 1000, home /home/wallyhao; stateVersion and passwords unchanged.
- Stylix owns the Emberlight colour source. Waybar/Fuzzel/Mako/Niri/Fcitx5
  reproduce current Folio appearance with colour-only changes, not Hearth styles.
- Noctalia is retired. Its persistent data is retained only for rollback.
- Systems/HM own essential desktop tools. The separate software flake/profile
  owns CLI, OMP and selected user apps. HM must not run profile installation.

## Safety and authorization

- Do not format/repartition the internal disk or change its labels/by-id/subvolumes.
  Existing Hearth storage identifiers are intentional compatibility state.
- No host activation/reboot/firmware writes or host profile installation as part
  of code migration. Actual deployment requires the user's deployment instruction
  and a fresh check of the running host/target mounts. Never install system-preview.
- User authorized reusing Folio node lists, subscription URLs/authentication and
  saved network connection DATA. This does not authorize replacing Ember's DNS,
  routing policy or module architecture with Folio's policy/framework.
- Private data remains in protected runtime/persistent files, never in Nix eval,
  the store, repository, chat, fixtures or unredacted logs. Use the bounded
  migration tool; local sudo is needed for root-owned source files.
- Do not change Folio's active network/proxy/credentials or copy its account,
  machine-id, personal input data or entire keyring.
- Do not give real block devices to QEMU; test fixtures remain virtual-only.

## Verification discipline

- Migration is now complete and the user explicitly requested validation before
  deployment. Run targeted static/build/CLI/login checks and one focused desktop
  VM if needed; do not repeat unrelated full VM suites or activate the host.
- Use path:. and --no-update-lock-file for later Nix operations. Preserve both locks.
- Record actual commands/results and pending work separately; never claim old
  Noctalia VM evidence validates the new shell. Do not record plans as PASS.
- Keep legacy state/CLI/profile migrations explicit. Do not fabricate renamed
  store paths, hand-write profile generations or clear old user data.
