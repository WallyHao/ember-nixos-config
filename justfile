set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

default:
    @just --list

info:
    ./scripts/ember info

check:
    nixfmt --check $(find . -name '*.nix' -not -path './result*' | sort)
    shellcheck scripts/ember
    ./scripts/ember check

build:
    ./scripts/ember build

software-build:
    nix build --no-link --print-out-paths --no-update-lock-file 'path:./software#workstation'

# Run on Folio after mounting the internal Ember disk; copies private DATA only.
migrate-folio-data:
    @./scripts/ember migrate-folio-data

# Proxy: status (default), on, off, check, import FILE.
proxy *args:
    @./scripts/ember proxy "$@"

# User software: install (default), list, history, rollback [GENERATION].
profile *args:
    @./scripts/ember profile "$@"

# Compatibility alias for the original bootstrap command.
profile-install:
    @./scripts/ember profile install

desktop-config:
    nix build --no-link --print-out-paths --no-update-lock-file path:.#checks.x86_64-linux.desktop-config

fmt:
    nixfmt $(find . -name '*.nix' -not -path './result*' | sort)

fmt-check:
    nixfmt --check $(find . -name '*.nix' -not -path './result*' | sort)

vm-accounts:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-accounts

vm-persistence:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-persistence

vm-offline-boot:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-offline-boot

vm-offline-desktop:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-offline-desktop

vm-offline-link:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-offline-link

vm-desktop:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-desktop

vm-user-environment:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-user-environment

vm-connectivity:
    nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.vm-connectivity

vm: vm-accounts vm-persistence vm-offline-boot vm-offline-desktop vm-offline-link vm-desktop vm-user-environment vm-connectivity
