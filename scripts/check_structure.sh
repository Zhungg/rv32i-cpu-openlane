#!/usr/bin/env bash
set -euo pipefail

required=(
  docs/spec rtl/pkg rtl/core rtl/frontend rtl/decode rtl/execute
  rtl/memory rtl/pipeline rtl/control rtl/commit rtl/trap
  tb/unit tb/core tb/memory_models tb/programs
  synth/yosys sta/opensta
  openlane/rv32i_core openlane/rv32i_core/runs
  openlane/rv32i_soc openlane/rv32i_soc/runs
  reports reports/openlane deliverables
)

missing=0
for dir in "${required[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "MISSING: $dir"
    missing=1
  fi
done

for keep in openlane/rv32i_core/runs/.gitkeep openlane/rv32i_soc/runs/.gitkeep; do
  if [[ ! -f "$keep" ]]; then
    echo "MISSING: $keep"
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "Project structure check: FAIL"
  exit 1
fi

echo "Project structure check: PASS"
