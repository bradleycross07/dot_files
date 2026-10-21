#!/usr/bin/env bash
# HuniePop 2: Double Date
export PROTON_USE_XALIA=0
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}winhttp=n,b"
exec "$@" -screen-fullscreen 0 -popupwindow -screen-width 2560 -screen-height 1440
