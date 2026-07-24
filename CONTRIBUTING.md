# Contributing

Thank you for your interest in the RV32I CPU OpenLane project.

## Project Scope

Contributions should remain aligned with the following areas:

- RV32I architectural and microarchitectural correctness
- SystemVerilog RTL implementation
- Self-checking RTL verification
- Synthesis and timing readiness
- OpenLane 2 / OpenROAD physical implementation
- Signoff reporting and reproducibility
- Technical documentation

## Development Workflow

1. Create a branch from the latest `main`.
2. Keep each change focused on one technical objective.
3. Run the local structural and RTL regression checks.
4. Push the branch and open a pull request.
5. Wait for all required GitHub Actions checks to pass.
6. Merge through a squash merge.

Direct pushes to `main` are not part of the supported workflow.

## Local Checks

Run the repository structure audit:

```bash
make check-structure
Run the frontend RTL regression:

Bash

bash scripts/test_frontend_baseline.sh
Inspect the resulting repository state:

Bash

git status --short
git diff --check
Pull Request Requirements
A pull request should include:

A clear technical objective

A concise summary of changed files

Verification commands and results

Timing, area, power, or QoR impact when applicable

Confirmation that generated run directories are not committed

Documentation updates for interface or flow changes

Generated Artifacts
Do not commit temporary or machine-generated artifacts unless they are
explicitly approved project evidence.

Examples that should normally remain untracked include:

OpenLane run directories

Tool caches

Simulation executables

Waveform dumps

Temporary synthesis databases

Local environment files

Large ODB, DEF, GDS, and log collections

Curated signoff summaries and small reproducibility artifacts may be committed
when they are required by the project documentation.

RTL Style
Use synthesizable SystemVerilog.

Avoid unintended latches.

Keep combinational and sequential logic clearly separated.

Use explicit reset behavior.

Document non-obvious pipeline, forwarding, hazard, CSR, LSU, and predictor logic.

Preserve ready/valid interface contracts.

Treat warnings introduced by a change as defects unless explicitly justified.

Physical Design Changes
Changes affecting the physical implementation should report, when relevant:

Clock period

Setup and hold WNS/TNS

Timing violation count

Standard-cell count and area

Core utilization

Routing DRC

Antenna violations

LVS status

The OpenLane run or configuration used for evaluation

Licensing
By contributing, you confirm that you have the right to submit the contribution
and that it may be distributed under the repository license.

Third-party code must retain its original copyright and license notices.
