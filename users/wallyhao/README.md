# wallyhao

Target account data:

- `bootstrap-password.nix`: initial SHA-512 crypt hash.
- `home.nix`: imports the Home Manager environment and preferences.
- `preferences.nix`: modifier and terminal font preference.
- `persistence.nix`: explicit user-state whitelist consumed by preservation.

The login password is defined in the phase plan and is never placed in the Nix
configuration. The user profile is installed by `wallyhao`, not by root or by
Home Manager activation.
