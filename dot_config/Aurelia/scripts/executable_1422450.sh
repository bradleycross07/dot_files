#!/usr/bin/env bash
# Deadlock
exec gamemoderun gamescope -w 1280 -h 720 -W 1280 -H 720 -r 144 -f -- mangohud "$@" -force-vulkan
