### !/bin/sh
#
#

LID_STATE=$(cat /proc/acpi/button/lid/*/state | awk '{print $2}')

if [ "$LID_STATE" = "closed" ]; then
	wlr-randr --output eDP-1 --off
else
	wlr-randr --output eDP-1 --on
fi
