#!/bin/sh
#
# ~/.xinitrc
#

# source xinitc.d scripts
if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# load .Xresources
[[ -f $HOME/.Xresources ]] && xrdb -merge $HOME/.Xresources

# remap caps lock to control, remap right alt to window key
setxkbmap -option ctrl:nocaps
xmodmap -e "keycode 108 = Super_L"
xmodmap -e "remove mod1 = Super_L"

# add font paths
xset fp default
[[ -d /usr/share/fonts/local ]] && xset +fp /usr/share/fonts/local
[[ -d /usr/share/fonts/OTF ]] && xset +fp /usr/share/fonts/OTF
[[ -d $HOME/.local/share/fonts ]] && xset +fp $HOME/.local/share/fonts
xset fp rehash

# Turn off monitor after 5min idle
#xset s off
#xset dpms 300 300 300
/usr/bin/xscreensaver -no-splash &

# increase mouse acceleration
xset m 3

# set WM to a name with Java recognises
wmname LG3D

# set background
sh $HOME/.fehbg


# Thinkpad OSD for mute and brightness
[[ -z "$(pidof tpb)" ]] && \
    [[ -x /usr/bin/tpb ]] && \
    [[ -w /dev/nvram ]] && \
    [[ -r /dev/nvram ]] && \
    /usr/bin/tpb -d

# Run WM
conky | while read -r; do xsetroot -name "$REPLY"; done &
exec dwm
