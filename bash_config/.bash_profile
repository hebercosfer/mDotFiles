# ~/.bash_profile: executed by bash(1) for login shells.
#
# Bash reads only the FIRST of ~/.bash_profile, ~/.bash_login, ~/.profile.
# This file exists solely so that ~/.profile is not shadowed: without it, a
# distro skeleton .bash_profile sourcing ~/.bashrc directly would silently
# skip ~/.profile (and therefore every PATH entry set there).

[ -f "$HOME/.profile" ] && . "$HOME/.profile"
