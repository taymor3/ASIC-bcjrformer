#!/usr/bin/env bash
# Run after the lab's Synopsys environment setup. No proprietary library needed.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
build_dir="$repo_root/tmp/vcs-position-add"
for tool in vlogan vcs; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing $tool: initialize the lab Synopsys environment first." >&2
    exit 127
  }
done
mkdir -p "$build_dir"
sources=()
while IFS= read -r source_path || [[ -n "$source_path" ]]; do
  source_path="${source_path%$'\r'}"
  [[ -z "$source_path" ]] || sources+=("$repo_root/$source_path")
done < "$repo_root/rtl/tests/sim/position_add.f"
cd "$build_dir"
vlogan -full64 -sverilog -timescale=1ns/1ps "${sources[@]}" -l analyze.log
vcs -full64 -debug_access+all tb_position_add -o simv -l elaborate.log
./simv -l simulate.log "$@"
