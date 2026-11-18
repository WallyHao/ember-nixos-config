#!/usr/bin/env bash
set -u

# A lone tiled window on the focused workspace grows to 100% of the working
# area width; the window keeps its height, the layout gaps and the focus ring.
# When a second tiled window appears, the tracked window returns to the default
# 50% column width so both columns sit side by side.

auto=""
declare -A known=()

contains() {
  case " $auto " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

add() {
  contains "$1" || auto="$auto $1"
}

remove_id() {
  local kept=""
  local id
  for id in $auto; do
    [ "$id" = "$1" ] || kept="$kept $id"
  done
  auto="$kept"
}

# set-column-width only acts on the focused column, so temporarily focus the
# target window and restore the previous focus afterwards.
set_column_width() {
  local id="$1" width="$2" prev
  prev=$(niri msg -j focused-window | jq -r '.id // empty')
  if [ "$prev" != "$id" ]; then
    if ! niri msg action focus-window --id "$id" >/dev/null 2>&1; then
      return 0
    fi
  fi
  niri msg action set-column-width "$width" >/dev/null 2>&1 || true
  if [ -n "$prev" ] && [ "$prev" != "$id" ]; then
    niri msg action focus-window --id "$prev" >/dev/null 2>&1 || true
  fi
}

process() {
  local windows workspaces focused_ws id count
  local -a ids

  windows=$(niri msg -j windows) || return
  workspaces=$(niri msg -j workspaces) || return

  focused_ws=$(jq -r '.[] | select(.is_focused) | .id' <<<"$workspaces" | head -n1)
  [ -n "$focused_ws" ] || return

  mapfile -t ids < <(jq -r --argjson ws "$focused_ws" \
    '.[] | select(.workspace_id == $ws and (.is_floating | not)) | .id' \
    <<<"$windows")
  count=${#ids[@]}

  if [ "$count" -eq 1 ]; then
    id=${ids[0]}
    if ! contains "$id"; then
      set_column_width "$id" "100%"
      add "$id"
    fi
  elif [ "$count" -gt 1 ]; then
    for id in "${ids[@]}"; do
      if contains "$id"; then
        set_column_width "$id" "50%"
        remove_id "$id"
      fi
    done
  fi

  # Drop ids for windows that no longer exist.
  local alive=""
  for id in $auto; do
    if jq -e --argjson id "$id" '.[] | select(.id == $id)' \
      >/dev/null <<<"$windows"; then
      alive="$alive $id"
    fi
  done
  auto="$alive"

  known=()
  while read -r id; do
    [ -n "$id" ] && known["$id"]=1
  done < <(jq -r '.[].id' <<<"$windows")
}

if [ -z "${NIRI_SOCKET:-}" ] || [ ! -S "${NIRI_SOCKET:-}" ]; then
  runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  for _ in $(seq 1 100); do
    sock=$(find "$runtime" -maxdepth 1 -name 'niri.wayland-*.sock' \
      -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)
    if [ -n "$sock" ]; then
      export NIRI_SOCKET="$sock"
      break
    fi
    sleep 0.1
  done
fi

[ -n "${NIRI_SOCKET:-}" ] || exit 1

while IFS= read -r line; do
  case "$line" in
    *'"WindowOpenedOrChanged"'*)
      id=$(jq -r '.WindowOpenedOrChanged.window.id // empty' <<<"$line")
      if [ -n "$id" ] && [ -z "${known[$id]:-}" ]; then
        process
      fi
      ;;
    *'"WindowClosed"'* | *'"WindowsChanged"'* | *'"WorkspaceActivated"'* | *'"WorkspacesChanged"'*)
      process
      ;;
  esac
done < <(niri msg -j event-stream)
