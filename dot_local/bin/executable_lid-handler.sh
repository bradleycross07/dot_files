#!/bin/sh

LID_STATE=$(cat /proc/acpi/button/lid/*/state | awk '{print $2}')

if [ "$LID_STATE" = "closed" ]; then
    kanshictl switch external_only 2>/dev/null || wlr-randr --output eDP-1 --off
    waylock
else
    kanshictl switch docked 2>/dev/null || wlr-randr --output eDP-1 --on
fi
