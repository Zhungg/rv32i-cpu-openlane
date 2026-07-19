#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TOP_MODULE="rv32i_core"
RTL_LIST="config/rtl.f"

mkdir -p \
    build/yosys \
    reports/yosys \
    logs/yosys

if ! command -v yosys >/dev/null 2>&1; then
    echo "ERROR: yosys not found in PATH"
    echo "Run this inside your OpenLane/OpenROAD/Yosys environment."
    exit 1
fi

if [[ ! -f "$RTL_LIST" ]]; then
    echo "ERROR: Missing ${RTL_LIST}"
    exit 1
fi

echo "=========================================="
echo "RV32I Yosys Synthesis-Readiness Check"
echo "=========================================="
echo "Top module : ${TOP_MODULE}"
echo "RTL list   : ${RTL_LIST}"
echo "Yosys      : $(yosys -V)"
echo

YOSYS_SCRIPT="build/yosys/check_synthesis_readiness.ys"

{
    echo "# Auto-generated Yosys synthesis-readiness script"
    echo "# Top: ${TOP_MODULE}"
    echo

    while IFS= read -r source_file; do
        [[ -z "$source_file" ]] && continue
        [[ "$source_file" =~ ^[[:space:]]*# ]] && continue

        if [[ ! -f "$source_file" ]]; then
            echo "ERROR: Missing RTL source: $source_file" >&2
            exit 1
        fi

        echo "read_verilog -sv ${source_file}"
    done < "$RTL_LIST"

    cat <<YOSYS

hierarchy -check -top ${TOP_MODULE}

proc
opt
check

stat

write_verilog -noattr build/yosys/${TOP_MODULE}.generic.v
YOSYS
} > "$YOSYS_SCRIPT"

echo "Generated Yosys script:"
echo "  ${YOSYS_SCRIPT}"
echo

yosys -l logs/yosys/check_synthesis_readiness.log \
      "$YOSYS_SCRIPT"

cp logs/yosys/check_synthesis_readiness.log \
   reports/yosys/check_synthesis_readiness.log

echo
echo "=========================================="
echo "Yosys synthesis-readiness check: PASS"
echo "Generated:"
echo "  logs/yosys/check_synthesis_readiness.log"
echo "  reports/yosys/check_synthesis_readiness.log"
echo "  build/yosys/${TOP_MODULE}.generic.v"
echo "=========================================="
