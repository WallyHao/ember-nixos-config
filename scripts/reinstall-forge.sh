#!/usr/bin/env bash
# Reinstall the desktop (forge) from Folio onto the external ZHITAI USB SSD.
#
# Phase 1, on the running Folio system:
#   sudo ./scripts/reinstall-forge.sh backup
#
# Phase 2, after booting a separate NixOS installer USB:
#   sudo mount -o ro /dev/nvme0n1p6 /backup
#   sudo /backup/ember-migration/install-forge.sh install
#
# The target disk is fixed by serial, never by /dev/sdX. The internal NVMe is
# not referenced. BACKUP_DEVICE defaults to the internal NVMe data partition;
# set it to another unmounted partition or external disk if needed.

set -euo pipefail

readonly TARGET_DISK=${TARGET_DISK:-/dev/disk/by-id/usb-ZHITAI_SPIRIT_PREMIUM_ZTE51T0AL262824228-0:0}
readonly BACKUP_DEVICE=${BACKUP_DEVICE:-/dev/nvme0n1p6}
readonly BACKUP_MOUNT=${BACKUP_MOUNT:-/backup}
readonly BACKUP_DIR=${BACKUP_DIR:-$BACKUP_MOUNT/ember-migration}
readonly SOURCE_HOME=${SOURCE_HOME:-/home/folio}
readonly REPO_NAME=${REPO_NAME:-ember-nixos-config}
readonly REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PASSWORD_FILE=$REPO/users/wallyhao/bootstrap-password.local.nix

BACKUP_WAS_MOUNTED=0

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "run as root (sudo)"; }
usage() {
  cat <<'EOF'
Usage: reinstall-forge.sh <backup|install>

  backup    on the running Folio system: create Workspace/repo tarballs,
            create the wallyhao initial password if missing, copy this script
  install   from a NixOS installer: format the external USB, install forge,
            restore Workspace from the backup

Environment overrides:
  BACKUP_DEVICE   device mounted at /backup (default /dev/nvme0n1p6)
  BACKUP_MOUNT    mount point (default /backup)
  TARGET_DISK     target by-id path (default the ZHITAI USB SSD)
  SOURCE_HOME     source home for Workspace (default /home/folio)
  FORCE=yes       skip the interactive DESTROY confirmation in install mode
EOF
}

mount_backup() {
  local mode=$1
  mkdir -p "$BACKUP_MOUNT"
  case "$BACKUP_MOUNT" in
    /mnt|/mnt/*) die "BACKUP_MOUNT must not be inside /mnt; disko unmounts /mnt" ;;
  esac
  if mountpoint -q "$BACKUP_MOUNT"; then
    if [ "$mode" = rw ]; then
      mount -o remount,rw "$BACKUP_MOUNT" 2>/dev/null || true
    fi
  else
    mount -o "$mode" "$BACKUP_DEVICE" "$BACKUP_MOUNT" ||
      die "cannot mount $BACKUP_DEVICE at $BACKUP_MOUNT"
    BACKUP_WAS_MOUNTED=1
  fi
}

ensure_password() {
  [ -s "$PASSWORD_FILE" ] && return
  command -v mkpasswd >/dev/null 2>&1 ||
    die "mkpasswd is missing; install whois or write $PASSWORD_FILE by hand"
  log "Set the initial password for wallyhao (input is hidden)"
  local hash
  hash=$(mkpasswd -m sha-512) || die "password hashing failed"
  (umask 077; printf '"%s"\n' "$hash" >"$PASSWORD_FILE")
  chmod 600 "$PASSWORD_FILE"
  # The script runs under sudo; keep the repository file readable by the
  # desktop account so ordinary flake builds do not fail after this step.
  chown "${SUDO_UID:-$(id -u)}:${SUDO_GID:-$(id -g)}" "$PASSWORD_FILE"
}

verify_tar() {
  tar -tf "$1" >/dev/null || die "backup archive is not readable: $1"
}

backup() {
  need_root
  [ -d "$SOURCE_HOME/Workspace" ] || die "missing $SOURCE_HOME/Workspace"
  ensure_password
  mount_backup rw

  local available required
  required=$(du -s --block-size=1G "$SOURCE_HOME/Workspace" | awk '{print $1}')
  required=$((required + 10))
  available=$(df --output=avail -B1G "$BACKUP_MOUNT" | tail -n1 | tr -d ' ')
  [ "${available:-0}" -ge "$required" ] ||
    die "need about ${required}G free on $BACKUP_MOUNT (found ${available:-0}G); use BACKUP_DEVICE=/dev/nvme0n1p4 or an external backup disk"

  mkdir -p "$BACKUP_DIR"
  log "Backing up Workspace (about 274G); this can take a while"
  tar --numeric-owner --xattrs --acls \
    -C "$SOURCE_HOME" -cpf "$BACKUP_DIR/workspace.tar" Workspace
  verify_tar "$BACKUP_DIR/workspace.tar"

  log "Backing up the repository, including .git and the local password file"
  tar -C "$(dirname "$REPO")" -cpf "$BACKUP_DIR/repo.tar" "$REPO_NAME"
  verify_tar "$BACKUP_DIR/repo.tar"

  install -m 0755 "${BASH_SOURCE[0]}" "$BACKUP_DIR/install-forge.sh"
  sync
  log "Backup complete: $BACKUP_DIR"
  ls -lh "$BACKUP_DIR"
}

install_system() {
  need_root
  [ -b "$TARGET_DISK" ] || die "target disk not found: $TARGET_DISK"

  local target_real transport
  target_real=$(readlink -f "$TARGET_DISK")
  transport=$(lsblk -dno TRAN "$target_real" | tr -d ' ')
  [ "$transport" = usb ] ||
    die "refusing: $TARGET_DISK is not a USB device (TRAN=${transport:-unknown})"

  local root_source
  root_source=$(findmnt -no SOURCE / || true)
  case "$root_source" in
    *sda*) die "boot a separate NixOS installer USB; the target is the current root disk" ;;
  esac

  mount_backup ro
  [ -s "$BACKUP_DIR/workspace.tar" ] || die "missing $BACKUP_DIR/workspace.tar"
  [ -s "$BACKUP_DIR/repo.tar" ] || die "missing $BACKUP_DIR/repo.tar"

  log "Target: $TARGET_DISK"
  log "This destroys the external USB SSD and installs Ember for forge."
  lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,MOUNTPOINTS "$target_real"
  if [ "${FORCE:-}" != yes ]; then
    local answer
    read -r -p "Type DESTROY to continue: " answer
    [ "$answer" = DESTROY ] || die "aborted"
  fi

  rm -rf /tmp/ember-install
  mkdir -p /tmp/ember-install
  tar -C /tmp/ember-install -xpf "$BACKUP_DIR/repo.tar"
  local repo=/tmp/ember-install/$REPO_NAME
  [ -d "$repo" ] || die "repository archive did not contain $REPO_NAME"
  [ -s "$repo/users/wallyhao/bootstrap-password.local.nix" ] ||
    die "repository archive lacks bootstrap-password.local.nix"

  cd "$repo"
  local nix_args=(--extra-experimental-features 'nix-command flakes')

  log "Partitioning $TARGET_DISK"
  local disko
  disko=$(nix "${nix_args[@]}" build --no-link --print-out-paths --no-update-lock-file \
    'path:.#nixosConfigurations.forge.config.system.build.diskoScript')
  "$disko"

  local path
  for path in /mnt /mnt/boot /mnt/nix /mnt/persist; do
    mountpoint -q "$path" || die "$path is not mounted after disko"
  done
  log "Mounted target:"
  findmnt -no SOURCE,TARGET /mnt /mnt/boot /mnt/nix /mnt/persist

  log "Building and installing Ember"
  nix "${nix_args[@]}" build --no-link --out-link /tmp/forge-system \
    --no-update-lock-file \
    'path:.#nixosConfigurations.forge.config.system.build.toplevel'
  nixos-install --root /mnt --system "$(readlink -f /tmp/forge-system)" \
    --no-root-passwd --no-channel-copy

  log "Restoring Workspace into @persist"
  mkdir -p /mnt/persist/home/wallyhao
  chown 1000:100 /mnt/persist/home/wallyhao
  chmod 0700 /mnt/persist/home/wallyhao
  tar --numeric-owner --xattrs --acls \
    -C /mnt/persist/home/wallyhao -xpf "$BACKUP_DIR/workspace.tar"
  chown -R 1000:100 /mnt/persist/home/wallyhao/Workspace
  sync

  umount -R /mnt

  log "Installation complete"
  cat <<'EOF'
Remove the installer USB and reboot. Select the external USB's EMBER_EFI
entry from the firmware boot menu. Log in as wallyhao with the password chosen
during the backup phase, then run:

  cd ~/Workspace/ember-nixos-config
  just apps
EOF
}

cleanup() {
  if [ "${BACKUP_WAS_MOUNTED:-0}" = 1 ] && mountpoint -q "$BACKUP_MOUNT"; then
    umount "$BACKUP_MOUNT" || true
  fi
}
trap cleanup EXIT

case ${1:-} in
  backup) backup ;;
  install) install_system ;;
  *) usage; exit 2 ;;
esac
