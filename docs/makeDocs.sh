#!/usr/bin/zsh

# some annoying chromium error
echo 0 | sudo tee /proc/sys/kernel/apparmor_restrict_unprivileged_userns

# run pandoc using the typst-bookly default
pandoc -d typst-bookly -o UserGuide.pdf UserGuide.md

