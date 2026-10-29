#!/bin/zsh
set -e
PROJECT_DIR="${0:A:h}"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PROJECT_DIR/game"
