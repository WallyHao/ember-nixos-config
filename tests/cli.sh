#!/usr/bin/env bash
# Focused CLI tests with mocked Nix/proxy backends; no host profile or service writes.
set -euo pipefail
project=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
source "$project/scripts/ember"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
repo="$temporary/repo"
export HOME="$temporary/home"
mkdir -p "$repo/software" "$HOME/.local/state/nix/profiles/profile"
cp "$project/software/bootstrap-workstation" "$project/software/legacy-workstations.json" "$repo/software/"
cd "$repo"
cache=$(< software/bootstrap-workstation)
manifest="$HOME/.local/state/nix/profiles/profile/manifest.json"
calls="$temporary/calls"
: > "$calls"
require_ember_user() { :; } # Only this sourced test bypasses the production guard.
ember-proxy() { printf '%s\0' "$@" > "$temporary/proxy-args"; }
expect_failure() {
  if "$@"; then
    echo "Expected failure: $*" >&2
    exit 1
  fi
}

# Exercise Just's positional forwarding too: paths with spaces stay one arg.
mkdir -p "$repo/scripts"
cat > "$repo/scripts/ember" <<'MOCK'
#!/usr/bin/env bash
printf '%s\0' "$@" > "${EMBER_TEST_ARGUMENTS:?}"
MOCK
chmod +x "$repo/scripts/ember"
export EMBER_TEST_ARGUMENTS="$temporary/just-args"
just --justfile "$project/justfile" --working-directory "$repo" proxy import 'a directory/provider.yaml'
mapfile -d '' -t forwarded < "$EMBER_TEST_ARGUMENTS"
[[ "${#forwarded[@]}" == 3 && "${forwarded[0]}" == proxy && "${forwarded[2]}" == 'a directory/provider.yaml' ]]
just --justfile "$project/justfile" --working-directory "$repo" profile install
mapfile -d '' -t forwarded < "$EMBER_TEST_ARGUMENTS"
[[ "${#forwarded[@]}" == 2 && "${forwarded[1]}" == install ]]

proxy_command import 'a directory/provider.yaml'
mapfile -d '' -t forwarded < "$temporary/proxy-args"
[[ "${#forwarded[@]}" == 2 && "${forwarded[1]}" == 'a directory/provider.yaml' ]]
expect_failure proxy_command off extra >/dev/null 2>&1
expect_failure profile_command install extra >/dev/null 2>&1
expect_failure profile_command rollback invalid >/dev/null 2>&1

nix() {
  printf '%s\n' "$1 ${2:-}" >> "$calls"
  case "$1 ${2:-}" in
    'build --no-link')
      [ "${fail_build:-false}" = false ] || return 1
      printf '%s\n' "$cache"
      ;;
    'profile list') cat "$manifest" ;;
    'profile install')
      [ "${fail_install:-false}" = false ] || return 1
      jq --arg url "path:$repo/software" --arg path "$cache" '
        .elements.managed={originalUrl:$url,attrPath:"packages.x86_64-linux.workstation",storePaths:[$path]}' \
        "$manifest" > "$temporary/new"
      mv "$temporary/new" "$manifest"
      ;;
    'profile upgrade')
      jq --arg path "$cache" '.elements.managed.storePaths=[$path]' "$manifest" > "$temporary/new"
      mv "$temporary/new" "$manifest"
      ;;
    'profile remove')
      jq 'del(.elements.legacy)' "$manifest" > "$temporary/new"
      mv "$temporary/new" "$manifest"
      ;;
    *) echo "unexpected mocked Nix command: $*" >&2; return 1 ;;
  esac
}
legacy_state() {
  jq -n --arg path "$cache" '{elements:{legacy:{storePaths:[$path]},other:{storePaths:["/nix/store/unrelated"]}}}' > "$manifest"
  : > "$calls"
}
legacy_state
fail_install=true
expect_failure profile_install >/dev/null 2>&1
jq -e '.elements.legacy and .elements.other' "$manifest" >/dev/null
expect_failure grep -q 'profile remove' "$calls"
fail_install=false
: > "$calls"
profile_install
jq -e '.elements.managed and .elements.other and (.elements.legacy == null)' "$manifest" >/dev/null
[[ $(grep -n 'profile install' "$calls" | cut -d: -f1) -lt $(grep -n 'profile remove' "$calls" | cut -d: -f1) ]]
: > "$calls"
profile_install
expect_failure grep -Eq 'profile (install|upgrade|remove)' "$calls"

# Returning declarations to their initial content must update a flake-tracked
# bundle rather than adding an old cache alongside it.
printf 'initial\n' > software/declaration
sha256sum software/declaration > software/bootstrap-fingerprint
jq '.elements.managed.storePaths=["/nix/store/older-ember-workstation"]' "$manifest" > "$temporary/new"
mv "$temporary/new" "$manifest"
: > "$calls"
profile_install
grep -q 'profile upgrade' "$calls"

# With an edited declaration, failed builds must not fall back to stale cache.
printf 'edited\n' > software/declaration
fail_build=true
: > "$calls"
expect_failure profile_install >/dev/null 2>&1
expect_failure grep -Eq 'profile (install|upgrade|remove)' "$calls"
fail_build=false

# Matching initial declarations can reuse the cache without evaluation/build.
printf 'initial\n' > software/declaration
legacy_state
profile_install
expect_failure grep -q '^build ' "$calls"
printf 'PASS: forwarding, validation, cache migration/failure, idempotence, declaration reset and offline bootstrap\n'
