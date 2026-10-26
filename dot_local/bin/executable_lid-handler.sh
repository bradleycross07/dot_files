#!/bin/sh
LID_STATE=$(awk '{print $2}' /proc/acpi/button/lid/*/state)

if [ "$LID_STATE" = "closed" ]; then
    kanshictl switch external_only 2>/dev/null || wlr-randr --output eDP-1 --off
    waylock -fork-on-lock
else
    kanshictl switch docked 2>/dev/null || wlr-randr --output eDP-1 --on
fi
