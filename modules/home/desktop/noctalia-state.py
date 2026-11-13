#!/usr/bin/env python3
"""Narrow, idempotent migration of Noctalia's runtime override file.

Noctalia overlays ~/.local/state/noctalia/settings.toml over the managed
config.toml. Keys that the UI persists for appearance would otherwise win over
Hearth's declarative intent. This script touches only those keys, keeps a
one-time backup, and writes a version marker so later user choices are not
fought on every activation.

Source of truth for the keys (Noctalia 5.4.1):
  src/config/config_schema.cpp   wallpaperSchema/themeSchema/pluginsSchema
  src/config/config_overrides.cpp setWallpaperPath/setThemeMode/setThemeColorScheme
  src/config/config_overrides.cpp firstRunWallpaperPath (trusts .setup-complete)
"""

import os
import shutil
import sys
import tempfile

import tomlkit

VERSION = "hearth-phase3-appearance-v3"

STATE_ROOT = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
STATE_DIR = os.path.join(STATE_ROOT, "noctalia")
SETTINGS = os.path.join(STATE_DIR, "settings.toml")
BACKUP = SETTINGS + ".pre-phase3-readability"
MARKER = os.path.join(STATE_DIR, ".hearth-phase3-appearance")
SETUP_MARKER = os.path.join(STATE_DIR, ".setup-complete")

# Appearance-owned override paths. Anything not listed here stays untouched.
REMOVALS = [
    ("wallpaper", "default", "path"),
    ("wallpaper", "last", "path"),
    ("wallpaper", "monitors"),
    ("wallpaper", "monitor"),
    ("wallpaper", "automation"),
    ("wallpaper", "enabled"),
    ("wallpaper", "fill_mode"),
    ("wallpaper", "fill_color"),
    ("wallpaper", "transition"),
    ("wallpaper", "transition_duration"),
    ("wallpaper", "edge_smoothness"),
    ("wallpaper", "transition_on_startup"),
    ("wallpaper", "directory"),
    ("wallpaper", "directory_light"),
    ("wallpaper", "directory_dark"),
    ("wallpaper", "per_monitor_directories"),
    ("theme", "mode"),
    ("theme", "source"),
    ("theme", "builtin"),
    ("theme", "community_palette"),
    ("theme", "custom_palette"),
    ("theme", "wallpaper_scheme"),
    ("theme", "shell_mode"),
    ("theme", "pure_black_dark"),
    ("theme", "sync_color_scheme"),
    ("plugins", "auto_update"),
    ("plugins", "source"),
]

# Only the layout/colours requested in the refinement are reset. Preserve
# plugin enablement, tray settings, audio devices and unrelated user state.
REMOVALS += [
    ("bar", "main", key)
    for key in (
        "position", "enabled", "reserve_space", "thickness", "margin_ends",
        "margin_edge", "margin_opposite_edge", "radius", "radius_top_left",
        "radius_top_right", "radius_bottom_left", "radius_bottom_right",
        "shadow", "background_opacity", "padding", "widget_spacing",
        "font_weight", "scale", "font_scale", "start", "center", "end",
    )
]
REMOVALS += [
    ("widget", "workspaces", key)
    for key in (
        "style", "show_labels", "show_icons", "pill_scale", "active_pill_size",
        "inactive_pill_size", "capsule_radius", "focused_color", "occupied_color",
        "empty_color", "urgent_color", "change_color_on_hover",
    )
]
REMOVALS += [
    ("widget", widget, "color")
    for widget in (
        "launcher", "media", "notifications", "clipboard", "control-center",
        "network", "volume", "battery", "clock", "session",
    )
]
REMOVALS += [
    ("widget", "media", key)
    for key in ("min_length", "max_length", "hide_when_no_media", "title_scroll")
]
REMOVALS.append(("widget", "clock", "format"))
REMOVALS += [
    ("widget", widget, key)
    for widget, keys in (
        ("network", ("show_label",)),
        ("volume", ("show_glyph", "show_label")),
        ("battery", ("display_mode", "show_label")),
    )
    for key in keys
]



def drop_path(doc, path):
    node = doc
    for key in path[:-1]:
        if key not in node or not hasattr(node[key], "items"):
            return False
        node = node[key]
    if path[-1] in node:
        del node[path[-1]]
        return True
    return False


def prune_empty(doc, path):
    """Remove tables emptied by the removals, never user data."""
    parents = []
    node = doc
    for key in path[:-1]:
        if key not in node or not hasattr(node[key], "items"):
            return
        parents.append((node, key))
        node = node[key]
    for parent, key in reversed(parents):
        if key in parent and hasattr(parent[key], "items") and len(parent[key]) == 0:
            del parent[key]


def migrate():
    if not os.path.isfile(SETTINGS):
        return False

    with open(SETTINGS, encoding="utf-8") as handle:
        original = handle.read()

    try:
        doc = tomlkit.parse(original)
    except Exception as error:  # keep the app-owned file intact on parse errors
        print(f"noctalia migration: cannot parse {SETTINGS}: {error}", file=sys.stderr)
        return None

    changed = False
    for path in REMOVALS:
        if drop_path(doc, path):
            changed = True
            prune_empty(doc, path)

    if not changed:
        return False

    if not os.path.exists(BACKUP):
        shutil.copy2(SETTINGS, BACKUP)

    rendered = tomlkit.dumps(doc)
    if rendered == original:
        return False

    directory = os.path.dirname(SETTINGS)
    fd, temporary = tempfile.mkstemp(prefix=".settings.", dir=directory, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(rendered)
        shutil.copymode(SETTINGS, temporary)
        os.replace(temporary, SETTINGS)
    except BaseException:
        if os.path.exists(temporary):
            os.unlink(temporary)
        raise
    return True


def main():
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)

    marker_version = ""
    if os.path.isfile(MARKER):
        with open(MARKER, encoding="utf-8") as handle:
            marker_version = handle.read().strip()
    changed = False
    if marker_version != VERSION:
        result = migrate()
        if result is not None:
            changed = result
            with open(MARKER, "w", encoding="utf-8") as handle:
                handle.write(VERSION + "\n")

    # Noctalia serves its bundled first-run wallpaper until this marker
    # exists. The setup wizard is disabled declaratively, so Hearth must state
    # "first run is over" itself or the configured solid fill would never show.
    if not os.path.exists(SETUP_MARKER):
        with open(SETUP_MARKER, "w", encoding="utf-8") as handle:
            handle.write("")

    if changed:
        print("noctalia migration: removed stale appearance overrides (backup kept)")


if __name__ == "__main__":
    main()