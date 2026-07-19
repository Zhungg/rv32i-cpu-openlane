#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

manifest="config/rtl_module_manifest.csv"

if [[ ! -f "$manifest" ]]; then
  echo "ERROR: Missing $manifest"
  exit 1
fi

missing=0
entries=0

while IFS=, read -r step path status; do
  [[ "$step" == "implementation_step" ]] && continue
  [[ -z "$path" ]] && continue

  entries=$((entries + 1))

  if [[ ! -f "$path" ]]; then
    echo "MISSING: $path"
    missing=$((missing + 1))
  fi
done < "$manifest"

if [[ "$missing" -ne 0 ]]; then
  echo
  echo "Module hierarchy check: FAIL"
  echo "Missing files: $missing"
  exit 1
fi

echo "Module hierarchy check: PASS"
echo "Manifest entries: $entries"
echo "SystemVerilog files: $(find rtl -type f -name '*.sv' | wc -l)"
