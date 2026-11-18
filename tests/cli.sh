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
mkdir -p "$repo/software/bootstrap" "$HOME/.local/state/nix/profiles/profile/bin" "$temporary/targets"
cp "$project/software/bootstrap/legacy-workstations.json" "$repo/software/bootstrap/"
manifest="$HOME/.local/state/nix/profiles/profile/manifest.json"
calls="$temporary/calls"
: >"$calls"
require_ember_user() { :; } # Only this sourced test bypasses the production guard.
ember-proxy() { printf '%s\0' "$@" >"$temporary/proxy-args"; }
expect_failure() {
  if "$@"; then
    echo "Expected failure: $*" >&2
    exit 1
  fi
}
set_desired() {
  mock_desired=("$@")
  : >"$repo/software/bootstrap/packages"
  for name in "${mock_desired[@]}"; do
    target="$temporary/targets/$name"
    mkdir -p "$target/bin"
    if [ "$name" = jq ]; then
      ln -sf "$(command -v jq)" "$target/bin/jq"
    else
      printf '#!/bin/sh\nexit 0\n' >"$target/bin/$name"
      chmod +x "$target/bin/$name"
    fi
    targets[$name]="$target"
    printf '%s %s\n' "$name" "$target" >>"$repo/software/bootstrap/packages"
  done
}
declare -A targets
declare -a mock_desired
set_desired gh git jq omp zen
ln -sf "$(command -v jq)" "$HOME/.local/state/nix/profiles/profile/bin/jq"
printf 'v1\n' >"$repo/software/declaration"
(cd "$repo" && sha256sum software/declaration >software/bootstrap/fingerprint)
cd "$repo"

# A profile entry with a different owner must never be replaced by reconciliation.
nix() {
  printf '%s\n' "$*" >>"$calls"
  case "$1 ${2:-}" in
    'eval --raw')
      printf '%s' "$(printf '%s\n' "${mock_desired[@]}")"
      ;;
    'build --no-link')
      if [ "${fail_build:-false}" = true ]; then
        return 1
      fi
      local arg name
      for arg in "$@"; do
        case "$arg" in
          *'#'*) name=${arg##*#} ;;
        esac
      done
      [ -n "${targets[$name]:-}" ] || return 1
      printf '%s\n' "${targets[$name]}"
      ;;
    'profile list')
      cat "$manifest"
      ;;
    'profile add')
      shift 2
      local priority=5 arg name path
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --priority) priority=$2; shift 2 ;;
          --profile) shift 2 ;;
          --no-update-lock-file) shift ;;
          *) break ;;
        esac
      done
      for arg in "$@"; do
        name=${arg##*#}
        path=${targets[$name]:-}
        [ -n "$path" ] || return 1
        jq --arg name "$name" --arg path "$path" --arg url "path:$repo/software" \
          --argjson priority "$priority" '
            .elements[$name] = {
              originalUrl: $url,
              attrPath: "packages.x86_64-linux." + $name,
              storePaths: [$path],
              priority: $priority
            }' "$manifest" >"$temporary/new"
        mv "$temporary/new" "$manifest"
      done
      ;;
    'profile upgrade')
      shift 2
      local arg name
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --profile) shift 2 ;;
          --no-update-lock-file) shift ;;
          *) break ;;
        esac
      done
      for arg in "$@"; do
        name=$arg
        jq --arg name "$name" --arg path "${targets[$name]:-}" '
          .elements[$name].storePaths = [$path]' "$manifest" >"$temporary/new"
        mv "$temporary/new" "$manifest"
      done
      ;;
    'profile remove')
      shift 2
      local arg name
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --profile) shift 2 ;;
          *) break ;;
        esac
      done
      for arg in "$@"; do
        name=$arg
        jq --arg name "$name" 'del(.elements[$name])' "$manifest" >"$temporary/new"
        mv "$temporary/new" "$manifest"
      done
      ;;
    *)
      echo "unexpected mocked Nix command: $*" >&2
      return 1
      ;;
  esac
}

profile_install_from_repo() { (cd "$repo" && profile_install); }

mkdir -p "$(dirname "$manifest")"
jq -n --arg url "path:$repo/software" '
  {
    version: 3,
    elements: {
      cargo: {
        originalUrl: "flake:nixpkgs",
        attrPath: "legacyPackages.x86_64-linux.cargo",
        storePaths: ["/nix/store/cargo"],
        priority: 5
      },
      uv: {
        originalUrl: "flake:nixpkgs",
        attrPath: "legacyPackages.x86_64-linux.uv",
        storePaths: ["/nix/store/uv"],
        priority: 5
      },
      workstation: {
        originalUrl: $url,
        attrPath: "packages.x86_64-linux.workstation",
        storePaths: ["/nix/store/old-workstation"],
        priority: 4
      }
    }
  }' >"$manifest"

# The changed declaration invalidates the fast path, so migration must build and reconcile.
printf 'v2\n' >"$repo/software/declaration"
: >"$calls"
profile_install_from_repo
jq -e '
  .elements.cargo and .elements.uv and
  (.elements.workstation == null) and
  (.elements.gh and .elements.git and .elements.jq and .elements.omp and .elements.zen)
' "$manifest" >/dev/null
grep -q 'profile add .*--priority 3' "$calls"
grep -q 'profile remove .*workstation' "$calls"

# Matching declaration and entries must not touch the profile.
printf 'v1\n' >"$repo/software/declaration"
(cd "$repo" && sha256sum software/declaration >software/bootstrap/fingerprint)
: >"$calls"
profile_install_from_repo
if grep -Eq '^build |profile (add|upgrade|remove)' "$calls"; then
  echo 'Fast path unexpectedly invoked Nix' >&2
  exit 1
fi

# Removing a package from the declaration removes only that managed entry.
set_desired gh git jq omp
printf 'v3\n' >"$repo/software/declaration"
: >"$calls"
profile_install_from_repo
jq -e '.elements.zen == null and .elements.gh and .elements.cargo and .elements.uv' "$manifest" >/dev/null
grep -q 'profile remove .*zen' "$calls"

# A failed build must leave the profile byte-for-byte unchanged.
cp "$manifest" "$temporary/before"
set_desired gh git jq omp new
printf 'v4\n' >"$repo/software/declaration"
: >"$calls"
fail_build=true
expect_failure profile_install_from_repo
cmp "$manifest" "$temporary/before"
if grep -Eq 'profile (add|upgrade|remove)' "$calls"; then
  echo 'Failed build unexpectedly changed the profile' >&2
  exit 1
fi

# Manual packages with a conflicting name are rejected, not replaced.
fail_build=false
set_desired gh git jq omp zen
jq '.elements.gh = {originalUrl:"flake:nixpkgs",attrPath:"legacyPackages.x86_64-linux.gh",storePaths:["/nix/store/manual-gh"],priority:5}' \
  "$manifest" >"$temporary/new"
cp "$temporary/new" "$manifest"
printf 'v5\n' >"$repo/software/declaration"
: >"$calls"
expect_failure profile_install_from_repo >/dev/null 2>"$temporary/error"
grep -q 'not managed by Ember' "$temporary/error"
jq -e '.elements.gh.originalUrl == "flake:nixpkgs"' "$manifest" >/dev/null
if grep -Eq 'profile (add|upgrade|remove)' "$calls"; then
  echo 'Manual conflict unexpectedly changed the profile' >&2
  exit 1
fi

# The public surface is argument-free recipes: the just layer prompts, and the
# backend receives exactly one non-interactive action.
mkdir -p "$repo/scripts"
cat >"$repo/scripts/ember" <<'MOCK'
#!/usr/bin/env bash
printf '%s\0' "$@" > "${EMBER_TEST_ARGUMENTS:?}"
MOCK
chmod +x "$repo/scripts/ember"
export EMBER_TEST_ARGUMENTS="$temporary/cli-arguments"
just_cli() { just --justfile "$project/justfile" --working-directory "$repo" "$@"; }
backend_args() { mapfile -d '' -t forwarded <"$EMBER_TEST_ARGUMENTS"; }
expect_cli_failure() {
  if "$@" >/dev/null 2>&1; then
    echo "Expected CLI failure: $*" >&2
    exit 1
  fi
}

# The listing stays small and every former verb is reachable from a menu.
just_cli </dev/null >/dev/null

# apps: Enter installs, digits select list/history, rollback prompts for a target.
just_cli apps </dev/null >/dev/null
backend_args
[[ "${#forwarded[@]}" == 2 && "${forwarded[0]}" == profile && "${forwarded[1]}" == install ]]
printf '2\n' | just_cli apps >/dev/null
backend_args
[[ "${#forwarded[@]}" == 2 && "${forwarded[1]}" == list ]]
printf '3\n' | just_cli apps >/dev/null
backend_args
[[ "${#forwarded[@]}" == 2 && "${forwarded[1]}" == history ]]
printf '5\n' | just_cli apps >/dev/null
backend_args
[[ "${#forwarded[@]}" == 1 && "${forwarded[0]}" == software-build ]]
printf '4\n7\n' | just_cli apps >/dev/null
backend_args
[[ "${#forwarded[@]}" == 3 && "${forwarded[1]}" == rollback && "${forwarded[2]}" == 7 ]]
printf '4\n\n' | just_cli apps >/dev/null
backend_args
[[ "${#forwarded[@]}" == 2 && "${forwarded[1]}" == rollback ]]

# vpn: a provider path with spaces stays one argument; a blank path is refused.
just_cli vpn </dev/null >/dev/null
backend_args
[[ "${#forwarded[@]}" == 2 && "${forwarded[0]}" == proxy && "${forwarded[1]}" == status ]]
printf '5\na directory/provider.yaml\n' | just_cli vpn >/dev/null
backend_args
[[ "${#forwarded[@]}" == 3 && "${forwarded[1]}" == import && "${forwarded[2]}" == 'a directory/provider.yaml' ]]
printf '5\n\n' | expect_cli_failure just_cli vpn
printf '9\n' | expect_cli_failure just_cli apps
printf '9\n' | expect_cli_failure just_cli vpn
printf '9\n' | expect_cli_failure just_cli vm
expect_cli_failure just_cli apps install </dev/null
expect_cli_failure just_cli vpn status </dev/null

# Every recipe body must parse as bash.
awk '
  /^[a-zA-Z][a-zA-Z0-9_-]*:/ { recipe = 1; next }
  recipe && /^    / { sub(/^    /, ""); print; next }
  { recipe = 0 }
' "$project/justfile" >"$temporary/recipe-bodies.sh"
bash -n "$temporary/recipe-bodies.sh"

proxy_command import 'a directory/provider.yaml'
mapfile -d '' -t forwarded <"$temporary/proxy-args"
[[ "${#forwarded[@]}" == 2 && "${forwarded[1]}" == 'a directory/provider.yaml' ]]
proxy_command nodes
mapfile -d '' -t forwarded <"$temporary/proxy-args"
[[ "${#forwarded[@]}" == 1 && "${forwarded[0]}" == nodes ]]
proxy_command select 'Node One'
mapfile -d '' -t forwarded <"$temporary/proxy-args"
[[ "${#forwarded[@]}" == 2 && "${forwarded[1]}" == 'Node One' ]]
expect_failure proxy_command select >/dev/null 2>&1
expect_failure proxy_command nodes extra >/dev/null 2>&1
expect_failure proxy_command off extra >/dev/null 2>&1
expect_failure profile_command install extra >/dev/null 2>&1
expect_failure profile_command rollback invalid >/dev/null 2>&1

printf 'PASS: profile reconciliation, manual-entry preservation, migration, idempotence, failure safety and argument-free CLI menus\n'
