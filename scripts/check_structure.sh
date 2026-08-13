#!/usr/bin/env bash
set -euo pipefail

required_dirs=(
  docs/spec
  rtl/pkg
  rtl/core
  rtl/frontend
  rtl/decode
  rtl/execute
  rtl/memory
  rtl/pipeline
  rtl/control
  rtl/commit
  rtl/trap
  tb/unit
  tb/core
  tb/memory_models
  tb/programs
  synth/yosys
  synth/yosys/work
  sta/opensta
  sta/opensta/work
  openlane/rv32i_core
  openlane/rv32i_core/runs
  reports
  reports/signoff
  deliverables
)

required_files=(
  openlane/rv32i_core/runs/.gitkeep
  synth/yosys/work/.gitkeep
  sta/opensta/work/.gitkeep
  tb/programs/README.md
  deliverables/README.md
)

missing=0

for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "MISSING DIR : $dir"
    missing=1
  fi
done

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "MISSING FILE: $file"
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "Project structure check: FAIL"
  exit 1
fi

echo "Project structure check: PASS"
