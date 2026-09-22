#!/usr/bin/env bash

# archipelago (modded silksong)

GAME_DIR="${AURELIA_GAME_DIR:-$HOME/.local/share/Steam/steamapps/common/Hollow Knight Silksong}"
SAVE_DIR="$HOME/.config/unity3d/Team Cherry/Hollow Knight Silksong"

"$HOME/.local/bin/discord-rpc-wrap" 1413176957381771337 \
  gamescope -w 1600 -h 900 -W 1600 -H 900 -r 144 -f -- mangohud "$GAME_DIR/run_bepinex.sh" "$@"

status=$?

dest="$HOME/Documents/Backups/silksong-ap-backups/$(date +%Y-%m-%d_%H%M)"
mkdir -p "$dest"
cp -a "$SAVE_DIR"/*.randomizerdata* "$dest"/ 2>/dev/null
cp -a "$SAVE_DIR"/62868043/*.randomizersave* "$dest"/ 2>/dev/null
cp -a "$SAVE_DIR"/62868043/randomizer_* "$dest"/ 2>/dev/null
cp -a "$SAVE_DIR"/62868043/Randomizer_* "$dest"/ 2>/dev/null

exit $status
