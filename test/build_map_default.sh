#!/usr/bin/env bash
# test/build_map_default.sh — TEST ONLY.
#
# Full map build using mkgmap's built-in "default" style and no TYP file,
# for comparing against the drive66 style during style development.
# Output goes to build-default/dist/ so it never clobbers the production
# output in build/dist/.
#
# Usage: test/build_map_default.sh [same flags as build_map.sh]

TEST_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

export STYLE=default          # built-in mkgmap style -> no --style-file, no TYP
export TYP_FILE=
export BUILD_DIR="$TEST_DIR/../build-default"

exec "$TEST_DIR/../build_map.sh" "$@"
