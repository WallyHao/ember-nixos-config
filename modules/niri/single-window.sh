#!/usr/bin/env bash
set -u

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

toggle() {
  niri msg action maximize-window-to-edges --id "$1" >/dev/null 2>&1 || true
}

set_half_width() {
  local id="$1" prev
  prev=$(niri msg -j focused-window | jq -r '.id // empty')
  if [ "$prev" != "$id" ]; then
    niri msg action focus-window --id "$id" >/dev/null 2>&1 || true
  fi
  niri msg action set-column-width "50%" >/dev/null 2>&1 || true
  if [ -n "$prev" ] && [ "$prev" != "$id" ]; then
    niri msg action focus-window --id "$prev" >/dev/null 2>&1 || true
  fi
}

window_json() {
  niri msg -j windows
}

is_maximized_to_edges() {
  local windows="$1" id="$2" maxw="$3"
  [ -n "$maxw" ] || return 1
  jq -e --argjson id "$id" --argjson maxw "$maxw" \
    '.[] | select(.id == $id and .layout.tile_size[0] >= ($maxw - 1))' \
    >/dev/null <<<"$windows"
}

is_fullscreen() {
  local windows="$1" id="$2" maxh="$3"
  [ -n "$maxh" ] || return 1
  jq -e --argjson id "$id" --argjson maxh "$maxh" \
    '.[] | select(.id == $id and .layout.tile_size[1] >= ($maxh - 1))' \
    >/dev/null <<<"$windows"
}

process() {
  local windows workspaces focused_ws output outputs maxw maxh id count
  local -a ids
  windows=$(window_json) || return
  workspaces=$(niri msg -j workspaces) || return

  focused_ws=$(jq -r '.[] | select(.is_focused) | .id' <<<"$workspaces" | head -n1)
  [ -n "$focused_ws" ] || return

  output=$(jq -r --argjson ws "$focused_ws" \
    '.[] | select(.id == $ws) | .output // empty' <<<"$workspaces")
  outputs=$(niri msg -j outputs) || return
  maxw=$(jq -r --arg output "$output" \
    '.[$output].logical.width // empty' <<<"$outputs")
  maxh=$(jq -r --arg output "$output" \
    '.[$output].logical.height // empty' <<<"$outputs")

  mapfile -t ids < <(jq -r --argjson ws "$focused_ws" \
    '.[] | select(.workspace_id == $ws and (.is_floating | not)) | .id' \
    <<<"$windows")
  count=${#ids[@]}

  if [ "$count" -eq 1 ]; then
    id=${ids[0]}
    if is_fullscreen "$windows" "$id" "$maxh"; then
      remove_id "$id"
    elif ! contains "$id"; then
      if is_maximized_to_edges "$windows" "$id" "$maxw"; then
        add "$id"
      else
        toggle "$id"
        add "$id"
      fi
    fi
  elif [ "$count" -gt 1 ]; then
    for id in "${ids[@]}"; do
      if contains "$id"; then
        if is_fullscreen "$windows" "$id" "$maxh"; then
          remove_id "$id"
          continue
        fi
        if is_maximized_to_edges "$windows" "$id" "$maxw"; then
          toggle "$id"
        fi
        set_half_width "$id"
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
