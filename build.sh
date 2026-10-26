#!/bin/sh
# Build the offline render test, and the SuperCollider UGen when headers are available.
set -eu
cd "$(dirname "$0")"

if [ -z "${SC_PATH:-}" ]; then
  for candidate in \
    "$HOME/supercollider" \
    /usr/local/include/SuperCollider \
    /usr/include/SuperCollider
  do
    if [ -f "$candidate/include/plugin_interface/SC_PlugIn.h" ] || [ -f "$candidate/plugin_interface/SC_PlugIn.h" ]; then
      SC_PATH=$candidate
      break
    fi
  done
fi

mkdir -p build
cd build
if [ -n "${SC_PATH:-}" ]; then
  cmake .. -DSC_PATH="$SC_PATH"
else
  cmake ..
fi

jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
# The granular templates are large. Two compiles at a time fits a norns.
if [ "$(uname -m)" = "armv7l" ] && [ "$jobs" -gt 2 ]; then
  jobs=2
fi
cmake --build . --target beads_render -j "$jobs"
./beads_render

if [ -n "${SC_PATH:-}" ]; then
  cmake --build . --target Beads -j "$jobs"
  echo "plugin built:"
  find . -name 'Beads.so' -o -name 'Beads.scx'
fi
