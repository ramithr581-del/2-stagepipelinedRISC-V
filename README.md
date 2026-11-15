# RISC-V 2-Stage Pipelined Processor

Starter repo for a two-stage pipelined RV32I processor (Groups 5 to 9). One member creates the group's repo with **Use this template** → **Create a new repository** (public), and adds the others as collaborators.

Spec: [Pipelined_RISCV/](Pipelined_RISCV/)

## Submit

1. Install the **`risc-n-roll-ci`** GitHub App on your group's repo (that exact repo, or CI never sees it).
2. Write your design, commit and push. `rnr-stage.yaml` suggests `Pipelined_RISCV/rtl.sv`; if you use other file names, edit the paths there (no spaces in paths).
3. Submit your repo link (one per group) through the course form.

CI checks each push on its next run, which can take a few hours. Its synthesizer (Yosys 0.33) cannot parse assignment patterns like `'{default: 0}`; use a `for` loop instead.
