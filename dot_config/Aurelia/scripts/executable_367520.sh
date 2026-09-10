#!/usr/bin/env bash
# Aurelia per-game launch script for app 367520 (Hollow Knight).
#
# Aurelia runs this script as a WRAPPER around the fully-resolved launch
# command: the resolved program and its arguments are passed to this script
# as "$@", and the entire launch environment (WINEPREFIX, WINEDLLOVERRIDES,
# STEAM_COMPAT_*, DXVK_HUD, ...) is already exported. A script that is just
# `exec "$@"` is therefore a transparent passthrough.
#
# Aurelia additionally exports:
#   AURELIA_APP_ID        - the Steam app id (367520)
#   AURELIA_APP_NAME      - the game's display name
#   AURELIA_GAME_DIR      - the game's install directory (if known)
#   AURELIA_LAUNCH_PROGRAM - the resolved program that would have run
#   AURELIA_LAUNCH_ARGS   - its arguments, space-joined
#
# Examples (uncomment one, or write your own):
#   exec gamemoderun mangohud "$@"
#   exec gamescope -W 2560 -H 1440 -- "$@"
#
# Default: run the resolved command unchanged.
export -n LD_LIBRARY_PATH
exec gamescope -w 1600 -h 900 -W 1600 -H 900 -r 144 -f -- mangohud "$@"
