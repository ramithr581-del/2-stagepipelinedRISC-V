# RISC-V 2-Stage Pipelined Processor

One module, `pipelined_riscv`: an RV32I core with a **two-stage pipeline**. CI checks the behaviour of your RTL with a
trusted harness that plays instruction memory and data memory, so you submit the core only (no memories in it).

### Module Specification

```SystemVerilog
module pipelined_riscv (
    input  logic        clk,
    input  logic        reset,          // asynchronous, active high
    input  logic [31:0] instruction,    // combinational read of instruction memory at `address`
    input  logic [31:0] mem_out,        // combinational load data for alu_out / fn3 (already extended)
    output logic [31:0] address,        // PC of the instruction being fetched (stage 1)
    output logic [31:0] alu_out,        // stage 2: ALU result / data memory address
    output logic [31:0] rs2_data,       // stage 2: store data
    output logic        mem_write,      // stage 2: committed store (never for a squashed instruction)
    output logic        mem_read,       // stage 2: load
    output logic [2:0]  fn3             // stage 2: funct3 of the load/store
);
```

### The two stages (course requirement)

| Stage | Contents |
|---|---|
| **1. IF + ID** | instruction fetch from instruction memory, PC management and update, decode, immediate generation, control signal generation (register read happens here too) |
| **2. EX + MEM + WB** | ALU, branch/jump resolution, data memory access, register write back |

with pipeline registers between the stages, correct handling of data and control hazards (forwarding and/or stalling
wherever needed) and correct PC updates for branches and jumps. Supported ISA: **RV32I** (no FENCE, ECALL, EBREAK, CSR).

### Ports (names, widths and directions are fixed)

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk` | in | 1 | clock, rising edge |
| `reset` | in | 1 | asynchronous, active high (`always_ff @(posedge clk or posedge reset)`) |
| `instruction` | in | 32 | the instruction at `address`: the memory read is **combinational** |
| `mem_out` | in | 32 | load data for `alu_out`, **combinational**, already extended for `fn3` (lb/lh sign-extended, lbu/lhu zero-extended, lw) |
| `address` | out | 32 | PC of the instruction being fetched (stage 1) |
| `alu_out` | out | 32 | stage 2: ALU result; for a load or store this is the data memory address |
| `rs2_data` | out | 32 | stage 2: the store data (the full `rs2` value; the memory uses the low 8/16/32 bits) |
| `mem_write` | out | 1 | stage 2: high only while a **committed** store is in stage 2 |
| `mem_read` | out | 1 | stage 2: a load is in stage 2 |
| `fn3` | out | 3 | stage 2: funct3 of the load/store (width and signedness) |

* The trusted memories: instruction memory is 512 words (bits `[10:2]` of `address`), data memory is 256 words
  (bits `[9:2]` of `alu_out`), zero-initialised, written on the clock edge when `mem_write` is high, byte/half/word by
  `fn3[1:0]`. The program is loaded at `0x8000_0000`.
* **Reset:** `address` becomes `32'h8000_0000`, all 32 registers become 0, and the pipeline is empty (no instruction in
  stage 2 may write a register or memory). The harness pulses `reset` once before the program starts.

### Behaviour that is pinned down

* RV32I semantics for every instruction. `x0` always reads 0 and writes to it are ignored (also by your forwarding).
* A branch/JAL/JALR is resolved in stage 2. A taken one redirects the PC to its target; the wrong-path instruction(s)
  behind it must have **no effect at all**: no register write, no store, no redirect of their own.
* JAL/JALR write `PC + 4` of the **jump itself** (not of the instruction currently being fetched). JALR clears bit 0 of
  its target. AUIPC adds the PC of the AUIPC itself, so stage 2 needs the PC of its own instruction.
* A load's data (`mem_out`) is available in the same cycle as its address, so a dependent instruction may take it by
  forwarding; stalling instead is also fine.

### What the CI checks

CI runs five programs (every instruction, plus many hazard cases) and compares the sequence of committed stores (address, funct3, data) against a trusted reference. Any hazard-handling strategy and any branch penalty is accepted; a design may take up to three cycles per instruction on average.

> [!IMPORTANT]
> Your module and port names are up to you, but the port count, directions, widths and behavior must match this spec. If your names differ, map them in `rnr-stage.yaml`.
