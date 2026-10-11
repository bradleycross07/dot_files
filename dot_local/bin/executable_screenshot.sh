#!/bin/sh
# usage: screenshot.sh full|region
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
f="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$1" in
    full)   grim "$f" ;;
    region) geom=$(slurp) || exit 1; grim -g "$geom" "$f" ;;
    *)      echo "usage: $0 full|region" >&2; exit 1 ;;
esac && wl-copy --type image/png < "$f"
