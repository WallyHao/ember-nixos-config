# Ember day-to-day commands. Run `just` to list them; every command takes no arguments.
set shell := ["bash", "-euo", "pipefail", "-c"]

# List the commands you need day to day.
default:
    @just --justfile '{{justfile()}}' --list

# Verify configuration and workflows with static checks, CLI tests, and flake evaluation.
check:
    rg --files --hidden -0 -g '*.nix' -g '!.git' -g '!result*' | xargs -0r nixfmt --check
    deadnix --fail .
    actionlint
    shellcheck scripts/ember
    bash tests/cli.sh
    ./scripts/ember check

# Build the system-preview toplevel; never installs or activates anything.
build:
    ./scripts/ember build

# Build VM checks: all of them, or one selected from a menu.
vm:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$#" -gt 0 ]; then
        echo 'vm takes no arguments; select a check from the menu.' >&2
        exit 2
    fi
    checks=(vm-accounts vm-persistence vm-offline-link vm-desktop vm-user-environment vm-connectivity vm-file-drop)
    printf 'VM checks:\n'
    for i in "${!checks[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${checks[$i]}"
    done
    printf 'Run [Enter=all, or one number]: '
    IFS= read -r choice || choice=''
    run_check() {
        nix build --no-link --no-update-lock-file "path:.#checks.x86_64-linux.$1"
    }
    case "${choice:-all}" in
        all)
            for name in "${checks[@]}"; do
                run_check "$name"
            done
            ;;
        *[!0-9]* | '')
            echo "Unknown selection: $choice" >&2
            exit 2
            ;;
        *)
            index=$((choice - 1))
            if [ "$index" -lt 0 ] || [ "$index" -ge "${#checks[@]}" ]; then
                echo "Unknown selection: $choice" >&2
                exit 2
            fi
            run_check "${checks[$index]}"
            ;;
    esac

# Rewrite .nix files with nixfmt; `just check` is the read-only gate.
format:
    rg --files --hidden -0 -g '*.nix' -g '!.git' -g '!result*' | xargs -0r nixfmt

# User software profile: install, list, history, rollback, or build-only preview.
apps:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$#" -gt 0 ]; then
        echo 'apps takes no arguments; select an action from the menu.' >&2
        exit 2
    fi
    cat <<'MENU'
    User software profile (software/selection/user-packages.nix):
      1) install   build and reconcile the declared packages (default)
      2) list      show installed profile entries
      3) history   show profile generations
      4) rollback  return to an earlier generation
      5) build     build every declared package without touching the profile
    MENU
    printf 'Action [Enter=install]: '
    IFS= read -r action || action=''
    case "${action:-1}" in
        1 | install) ./scripts/ember profile install ;;
        2 | list) ./scripts/ember profile list ;;
        3 | history) ./scripts/ember profile history ;;
        4 | rollback)
            ./scripts/ember profile history
            printf 'Generation to restore [Enter=previous]: '
            IFS= read -r generation || generation=''
            if [ -n "$generation" ]; then
                ./scripts/ember profile rollback "$generation"
            else
                ./scripts/ember profile rollback
            fi
            ;;
        5 | build) ./scripts/ember software-build ;;
        *)
            echo "Unknown action: $action" >&2
            exit 2
            ;;
    esac

# Mihomo proxy: status, on, off, check, or import a subscription file.
vpn:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$#" -gt 0 ]; then
        echo 'vpn takes no arguments; select an action from the menu.' >&2
        exit 2
    fi
    cat <<'MENU'
    Mihomo proxy:
      1) status  show the current state (default)
      2) on      enable the proxy
      3) off     disable the proxy
      4) check   validate the stored configuration
      5) import  install or replace nodes from a private YAML file
      6) nodes   list nodes and the current selection
      7) select  pin one node, AUTO, or DIRECT
    MENU
    printf 'Action [Enter=status]: '
    IFS= read -r action || action=''
    case "${action:-1}" in
        1 | status) ./scripts/ember proxy status ;;
        2 | on) ./scripts/ember proxy on ;;
        3 | off) ./scripts/ember proxy off ;;
        4 | check) ./scripts/ember proxy check ;;
        5 | import)
            printf 'Provider YAML path: '
            IFS= read -r provider || provider=''
            if [ -z "$provider" ]; then
                echo 'No file given; nothing imported.' >&2
                exit 2
            fi
            ./scripts/ember proxy import "$provider"
            ;;
        6 | nodes) ./scripts/ember proxy nodes ;;
        7 | select)
            printf 'Node name: '
            IFS= read -r node || node=''
            if [ -z "$node" ]; then
                echo 'No node given; selection unchanged.' >&2
                exit 2
            fi
            ./scripts/ember proxy select "$node"
            ;;
        *)
            echo "Unknown action: $action" >&2
            exit 2
            ;;
    esac
