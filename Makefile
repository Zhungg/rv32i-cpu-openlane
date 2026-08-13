SHELL := /bin/bash

.PHONY: help tree check-structure openlane-core openlane-soc clean clean-openlane-runs

help:
	@echo "RV32I CPU project skeleton"
	@echo "  make tree                 Hiển thị cấu trúc thư mục"
	@echo "  make check-structure      Kiểm tra các thư mục bắt buộc"
	@echo "  make openlane-core        Chạy OpenLane 2 cho rv32i_core"
	@echo "  make openlane-soc         Chạy OpenLane 2 cho rv32i_soc"
	@echo "  make clean                Xóa output mô phỏng/build tạm"
	@echo "  make clean-openlane-runs  Xóa toàn bộ OpenLane runs (có chủ ý)"

tree:
	@find . -maxdepth 4 -type d | sort

check-structure:
	@./scripts/check_structure.sh

openlane-core:
	@./scripts/run_openlane.sh rv32i_core

openlane-soc:
	@./scripts/run_openlane.sh rv32i_soc

clean:
	@rm -rf obj_dir sim_build build
	@find sim -type f \( -name '*.vcd' -o -name '*.fst' -o -name '*.log' -o -name '*.vvp' \) -delete
	@echo "Temporary simulation/build outputs removed. OpenLane runs were preserved."

clean-openlane-runs:
	@find openlane -type d -path '*/runs' -print0 | while IFS= read -r -d '' d; do \
		find "$$d" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} +; \
	done
	@echo "All generated OpenLane run contents removed; .gitkeep files preserved."

.PHONY: check-instruction-spec
check-instruction-spec:
	python3 scripts/check_instruction_spec.py

.PHONY: check-microarchitecture-spec
check-microarchitecture-spec:
	python3 scripts/check_microarchitecture_spec.py

.PHONY: check-module-hierarchy
check-module-hierarchy:
	bash scripts/check_module_hierarchy.sh

.PHONY: lint-packages
lint-packages:
	bash scripts/lint_packages.sh

.PHONY: test-leaf-datapath
test-leaf-datapath:
	bash scripts/test_leaf_datapath.sh

.PHONY: test-decoder
test-decoder:
	bash scripts/test_decoder.sh

.PHONY: test-execute-support
test-execute-support:
	bash scripts/test_execute_support.sh

.PHONY: test-pipeline-registers
test-pipeline-registers:
	bash scripts/test_pipeline_registers.sh

.PHONY: test-frontend-baseline
test-frontend-baseline:
	bash scripts/test_frontend_baseline.sh

.PHONY: test-baseline-core
test-baseline-core:
	bash scripts/test_baseline_core.sh

.PHONY: test-memory-interface-shell
test-memory-interface-shell:
	bash scripts/test_memory_interface_shell.sh

.PHONY: test-lsu-leaf
test-lsu-leaf:
	bash scripts/test_lsu_leaf.sh

.PHONY: test-lsu-controller
test-lsu-controller:
	bash scripts/test_lsu_controller.sh

.PHONY: test-lsu-core
test-lsu-core:
	bash scripts/test_lsu_core.sh

.PHONY: test-load-use-hazard
test-load-use-hazard:
	bash scripts/test_load_use_hazard.sh

.PHONY: test-forwarding-core
test-forwarding-core:
	bash scripts/test_forwarding_core.sh

.PHONY: test-basic-trap
test-basic-trap:
	bash scripts/test_basic_trap.sh

.PHONY: test-trap-csr
test-trap-csr:
	bash scripts/test_trap_csr.sh

.PHONY: test-system-trap-mret
test-system-trap-mret:
	bash scripts/test_system_trap_mret.sh

.PHONY: test-csr-instructions
test-csr-instructions:
	bash scripts/test_csr_instructions.sh

.PHONY: test-lsu-exception-trap
test-lsu-exception-trap:
	bash scripts/test_lsu_exception_trap.sh

.PHONY: test-branch-predictor-foundation
test-branch-predictor-foundation:
	bash scripts/test_branch_predictor_foundation.sh

.PHONY: test-bpu-fetch-integration
test-bpu-fetch-integration:
	bash scripts/test_bpu_fetch_integration.sh

.PHONY: test-bpu-qor-counters
test-bpu-qor-counters:
	bash scripts/test_bpu_qor_counters.sh

.PHONY: test-step7-regression
test-step7-regression:
	bash scripts/test_step7_regression.sh

.PHONY: check-rtl-source-list
check-rtl-source-list:
	bash scripts/check_rtl_source_list.sh

.PHONY: check-yosys-synthesis-readiness
check-yosys-synthesis-readiness:
	bash scripts/check_yosys_synthesis_readiness_sv2v.sh

.PHONY: generate-openlane-rtl
generate-openlane-rtl:
	bash scripts/generate_openlane_rtl.sh

.PHONY: extract-openlane-qor
extract-openlane-qor:
	bash scripts/extract_openlane_qor.sh

.PHONY: test-soc
test-soc:
	bash scripts/test_soc.sh

.PHONY: test-soc-wb
test-soc-wb:
	bash scripts/test_soc_wb.sh

.PHONY: test-mdu
test-mdu:
	bash scripts/test_rv32m.sh

.PHONY: test-cache
test-cache:
	bash scripts/test_cache.sh

.PHONY: test-pmp
test-pmp:
	bash scripts/test_pmp.sh

.PHONY: test-power
test-power:
	bash scripts/test_power.sh

.PHONY: test-priv
test-priv:
	bash scripts/test_priv.sh

.PHONY: test-plic
test-plic:
	bash scripts/test_plic.sh

.PHONY: test-compliance
test-compliance:
	bash scripts/test_compliance.sh

.PHONY: test-sram-macro
test-sram-macro:
	bash scripts/test_sram_macro.sh

.PHONY: test-all
test-all:
	make test-compliance
	make test-sram-macro
	make test-plic
	make test-priv
	make test-power
	make test-pmp
	make test-cache
	make test-mdu
	make test-soc-wb
	make test-soc
	make test-step7-regression
	bash scripts/check_structure.sh
	bash scripts/check_module_hierarchy.sh
	bash scripts/check_rtl_source_list.sh

