#!/usr/bin/env bash
# Deadlock
exec gamemoderun gamescope -w 1280 -h 720 -W 2560 -H 1440 -f -S integer -F nearest -- mangohud "$@"
