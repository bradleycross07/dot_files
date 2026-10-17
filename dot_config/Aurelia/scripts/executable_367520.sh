#!/usr/bin/env bash
# Hollow Knight
exec gamemoderun gamescope -w 1600 -h 900 -W 1600 -H 900 -r 144 -f --framerate-limit 144 -- bwrap --dev-bind / / --unshare-net -- "$@" -force-glcore
