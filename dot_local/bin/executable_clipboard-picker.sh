### !/bin/sh
#
#

# clipboard to output onto fuzzel
cliphist list | fuzzel --dmenu | cliphist decode | wl-copy
