#!/bin/sh
geom=$(slurp) || exit 0
grim -g "$geom" - | wl-copy --type image/png
