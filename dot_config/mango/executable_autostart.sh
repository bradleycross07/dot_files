#!/bin/sh

wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 80%

/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1 &

dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY

swayidle -w \
	timeout 600   'waylock -fork-on-lock' \
	timeout 900   'mmsg dispatch sleep_monitor,eDP-1; mmsg dispatch sleep_monitor,HDMI-A-1' \
        resume        'mmsg dispatch wakeup_monitor,eDP-1; mmsg dispatch wakeup_monitor,HDMI-A-1' \
	timeout 10800 'systemctl poweroff' \
	before-sleep  'waylock -fork-on-lock' &

kanshi &

sc-controller &

easyeffects --gapplication-service &

wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &

/run/current-system/sw/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

swaybg -i ~/Pictures/silksong.jpg -m fill &

pkill gammastep
gammastep -l 51.5:-0.1 &

waybar &
