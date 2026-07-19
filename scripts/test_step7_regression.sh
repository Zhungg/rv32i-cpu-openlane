#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "RV32I Step 7 Frontend/BPU Regression"
echo "=========================================="

run_target() {
    local target="$1"

    echo
    echo "------------------------------------------"
    echo "Running: make ${target}"
    echo "------------------------------------------"

    make "${target}"
}

# Predictor leaf blocks
run_target test-branch-predictor-foundation

# Predictor integration
run_target test-bpu-fetch-integration

# Predictor QoR counters
run_target test-bpu-qor-counters

# Core sanity after BPU integration
run_target test-baseline-core
run_target test-forwarding-core
run_target test-load-use-hazard

# LSU/trap/CSR sanity after frontend change
run_target test-lsu-core
run_target test-basic-trap
run_target test-trap-csr
run_target test-system-trap-mret
run_target test-csr-instructions
run_target test-lsu-exception-trap

echo
echo "=========================================="
echo "RV32I Step 7 Frontend/BPU Regression: PASS"
echo "=========================================="
