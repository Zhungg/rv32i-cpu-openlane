#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

RTL_LIST="config/rtl.f"
ERRORS=0

echo "=========================================="
echo "RV32I RTL Source List Audit"
echo "=========================================="
echo "Source list: ${RTL_LIST}"
echo

if [[ ! -f "$RTL_LIST" ]]; then
    echo "ERROR: Missing ${RTL_LIST}"
    exit 1
fi

echo "[1/5] Checking listed files exist"

while IFS= read -r source_file; do
    [[ -z "$source_file" ]] && continue
    [[ "$source_file" =~ ^# ]] && continue

    if [[ ! -f "$source_file" ]]; then
        echo "ERROR: Missing source file: $source_file"
        ERRORS=$((ERRORS + 1))
    fi
done < "$RTL_LIST"

if [[ "$ERRORS" -ne 0 ]]; then
    echo "File existence check: FAIL"
    exit 1
fi

echo "File existence check: PASS"

echo
echo "[2/5] Checking source list does not contain testbench/simulation files"

if grep -En "tb/|testbench|_tb|tb_" "$RTL_LIST"; then
    echo "ERROR: config/rtl.f contains non-synthesizable testbench source"
    exit 1
fi

echo "No testbench files in config/rtl.f: PASS"

echo
echo "[3/5] Checking duplicate entries"

DUPLICATES="$(grep -v '^[[:space:]]*$' "$RTL_LIST" | grep -v '^[[:space:]]*#' | sort | uniq -d || true)"

if [[ -n "$DUPLICATES" ]]; then
    echo "ERROR: Duplicate entries found:"
    echo "$DUPLICATES"
    exit 1
fi

echo "Duplicate check: PASS"

echo
echo "[4/5] Checking top module exists"

if ! grep -Rnw "rtl/core" -e "module rv32i_core" >/dev/null 2>&1; then
    echo "ERROR: Top module rv32i_core not found under rtl/core"
    exit 1
fi

echo "Top module rv32i_core found: PASS"

echo
echo "[5/5] Checking key RTL modules are present"

REQUIRED_MODULES=(
    "rtl/core/rv32i_core.sv"
    "rtl/core/rv32i_datapath.sv"
    "rtl/frontend/rv32i_fetch_unit.sv"
    "rtl/predict/rv32i_branch_predictor.sv"
    "rtl/decode/rv32i_decoder.sv"
    "rtl/execute/rv32i_alu.sv"
    "rtl/memory/rv32i_lsu.sv"
    "rtl/control/rv32i_hazard_unit.sv"
    "rtl/control/rv32i_forwarding_unit.sv"
    "rtl/trap/rv32i_csr_file.sv"
)

for required in "${REQUIRED_MODULES[@]}"; do
    if ! grep -Fxq "$required" "$RTL_LIST"; then
        echo "ERROR: Required module missing from ${RTL_LIST}: $required"
        exit 1
    fi
done

echo "Required module check: PASS"

echo
echo "=========================================="
echo "RV32I RTL Source List Audit: PASS"
echo "=========================================="
