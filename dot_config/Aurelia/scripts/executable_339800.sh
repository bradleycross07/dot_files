#!/usr/bin/env bash
# Aurelia per-game launch script for app 339800 (HuniePop).
dir="${AURELIA_GAME_DIR:-$HOME/.local/share/Steam/steamapps/common/HuniePop}"
cd "$dir" || exit 1
echo 339800 > steam_appid.txt
export SteamAppId=339800 SteamGameId=339800
unset LD_LIBRARY_PATH   # Aurelia adds Steam scout libs for the 32-bit exe; they break gamescope
exec "$HOME/.local/bin/discord-rpc-wrap" 363425169051615262 gamescope -W 2560 -H 1440 -f -r 144 -- bwrap --dev-bind / / --unshare-net --chdir "$dir" -- ./HuniePop.x86_64
