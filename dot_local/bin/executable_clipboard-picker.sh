#!/bin/sh
sel=$(cliphist list | fuzzel --dmenu) || exit 0
printf '%s\n' "$sel" | cliphist decode | wl-copy
