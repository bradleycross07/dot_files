#!/usr/bin/env bash
# Hollow Knight: Silksong
exec "$HOME/.local/bin/discord-rpc-wrap" 1413176957381771337 \
     gamemoderun gamescope -w 1600 -h 900 -W 1600 -H 900 -r 144 -f --framerate-limit 144 -- bwrap --dev-bind / / --unshare-net -- "$@"
