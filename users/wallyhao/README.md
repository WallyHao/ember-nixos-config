# wallyhao

Target account data:

- `bootstrap-password.nix`: loader for the local initial SHA-512 hash.
- `bootstrap-password.local.nix`: the hash itself, git-ignored and never committed.
- `home.nix`: imports the Home Manager environment and preferences.
- `preferences.nix`: modifier and terminal font preference.
- `persistence.nix`: explicit user-state whitelist consumed by preservation.

The tracked loader falls back to an unusable placeholder hash when the local
file is absent, so evaluation and CI still build. Create the local file before
building an installable system:

```sh
printf '"%s"\n' "$(mkpasswd -m sha-512)" > users/wallyhao/bootstrap-password.local.nix
```

The user profile is installed by `wallyhao`, not by root or by Home Manager
activation.
