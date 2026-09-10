#!/bin/sh

# gnome keyring
gnome-keyring-daemon --start --components=secrets &

# polkit authentication agent
/usr/libexec/polkit-gnome-authentication-agent-1 &

# audio
pipewire &

# audio processing
( while ! wpctl status >/dev/null 2>&1; do sleep 0.2; done
  pipewire-pulse &
  easyeffects --gapplication-service ) &

# monitors
kanshi &

# night light
gammastep &

# clipboard history
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &

# idling
swayidle -w \
  timeout 600   'waylock -fork-on-lock' \
  timeout 900   'wlopm --off "*"' \
  resume        'wlopm --on "*"' \
  timeout 10800 'doas poweroff' \
  before-sleep  'waylock -fork-on-lock' &

# inhibit idle when audio is playing
sway-audio-idle-inhibit &
