#!/bin/sh

wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 80%

gnome-keyring-daemon --start --components=secrets &

dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY

swayidle -w \
	timeout 1200 'waylock' \
	timeout 3600 'systemctl suspend' \
	before-sleep 'waylock' &

kanshi &

easyeffects --gapplication-service &

wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &

/run/current-system/sw/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

swaybg -i ~/Pictures/silksong.jpg -m fill &

#pkill gammastep
#gammastep &

waybar &
