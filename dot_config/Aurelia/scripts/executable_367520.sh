#!/usr/bin/env bash
exec gamescope -w 1600 -h 900 -W 1600 -H 900 -r 144 -f --framerate-limit 144 -- "$@"
