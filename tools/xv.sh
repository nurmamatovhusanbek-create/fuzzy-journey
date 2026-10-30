#!/bin/bash
# xvfb-run with fresh game settings: the game reads and writes user://settings.cfg, and a text size or layout that one test leaves there changes the next test's picture.
# The suites export XDG_DATA_HOME (a temp folder), so this never touches the real settings.
[ -n "$XDG_DATA_HOME" ] && rm -rf "$XDG_DATA_HOME/godot/app_userdata"
exec xvfb-run "$@"
