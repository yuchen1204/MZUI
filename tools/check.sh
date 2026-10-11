#!/usr/bin/env bash
# Run against your own Project Zomboid installation; no game files are bundled.
set -euo pipefail
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${GAME_DIR:?Set GAME_DIR to your Project Zomboid installation}"
MOD_DIR=${MOD_DIR:-"$PROJECT_DIR/mods/MZUI"}
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT
javac -cp "$GAME_DIR/projectzomboid.jar" -d "$BUILD_DIR" \
    "$PROJECT_DIR/tools/SyntaxCheck.java" "$PROJECT_DIR/tools/LayoutCheck.java"
cd "$GAME_DIR"
java -cp "projectzomboid.jar:$BUILD_DIR" SyntaxCheck "$MOD_DIR"
java -cp "projectzomboid.jar:$BUILD_DIR" LayoutCheck "$MOD_DIR"
