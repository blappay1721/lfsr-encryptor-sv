# LFSR Message Encryption

A SystemVerilog hardware encryptor that scrambles an ASCII message using a **6-bit linear feedback shift register (LFSR)** as a pseudo-random keystream. The design reads its configuration and plaintext from an on-chip data memory, prepends a preamble of padding characters, XORs every byte with the current LFSR state, and writes the encrypted result back into memory. A self-checking testbench computes the same encryption in software and compares it byte by byte.

## How It Works

1. **Configuration load:** at startup the control sequencer reads three configuration bytes from data memory:
   - `dat_mem[61]`: preamble length (7-12 bytes)
   - `dat_mem[62]`: LFSR feedback tap pattern
   - `dat_mem[63]`: LFSR starting state (any nonzero 6-bit value)
2. **Preamble:** for `pre_len` cycles, the ASCII underscore `_` (`0x5F`) is XORed with `{2'b00, LFSR}` and written to `dat_mem[64]`, `dat_mem[65]`, ...; the LFSR advances every cycle.
3. **Message:** the plaintext is read from data memory, XORed with the LFSR state, and written after the preamble.
4. **Done:** `done` is raised once the sequence is complete, and the testbench checks `dat_mem[64:127]`.

Only the low 6 bits of each byte are scrambled, so ASCII characters in the `0x40`-`0x7F` range stay in that range after encryption.

### LFSR

`lfsr6` shifts left by one each enabled cycle, feeding back the parity (XOR reduction) of `state & taps`. Any of the six maximal-length 6-bit tap patterns can be used; each produces a 63-state sequence:

| Index | Taps    |
|-------|---------|
| 0     | `6'h21` |
| 1     | `6'h2D` |
| 2     | `6'h30` |
| 3     | `6'h33` |
| 4     | `6'h36` |
| 5     | `6'h39` |

### Data memory map

| Address    | Contents                         |
|------------|----------------------------------|
| `[0:60]`   | Plaintext message (padded with `_`) |
| `[61]`     | Preamble length                  |
| `[62]`     | LFSR tap pattern (bits `[5:0]`)  |
| `[63]`     | LFSR starting state (bits `[5:0]`) |
| `[64:127]` | Encrypted output (preamble + message) |

## File Breakdown

| File              | Description |
|-------------------|-------------|
| `top_level.sv`    | Top level: program-counter-driven control sequencer, configuration registers, and wiring to memory and LFSR |
| `lfsr6.sv`        | 6-bit LFSR with loadable taps and starting state |
| `dat_mem.sv`      | 256 x 8 data memory: combinational read, clocked write |
| `lfsr_encrypt_tb.sv` | Self-checking testbench (module `lfsr_encrypt_tb`) |
| `playground_tb.sv` | Alternate testbench for experimenting with tap patterns and preamble lengths; also dumps waveforms to `dump.vcd` (module `playground_tb`) |

## Simulating in ModelSim / Questa

**Requirements:** ModelSim, ModelSim-Intel FPGA Edition, or Questa-Intel FPGA Starter Edition (any simulator with SystemVerilog-2012 support should work).

### Option A: GUI

1. **File → New → Project**. Set the project location to this folder and keep the default library `work`.
2. **Add Existing File** and add all `.sv` files.
3. **Compile → Compile All**.
4. **Simulate → Start Simulation**, expand `work`, select `lfsr_encrypt_tb` (or `playground_tb`), and click **OK**.
5. Type `run -all` in the transcript. The simulation stops itself with `$stop`.

### Option B: Command line / transcript

From this folder:

```tcl
vlib work
vlog -sv dat_mem.sv lfsr6.sv top_level.sv lfsr_encrypt_tb.sv playground_tb.sv
vsim -c work.lfsr_encrypt_tb -do "run -all; quit -f"
```

Use `work.playground_tb` to run the alternate testbench. Drop `-c` and `quit -f` to run with the GUI and waveform viewer.

### Configuring a run

In the testbench, edit:

- `str`: the plaintext message (characters in `0x40`-`0x7F`)
- `i`: tap pattern index (0-5)
- `j`: preamble length (clamped to 7-12)
- `lfsr_state`: LFSR starting state (nonzero)

### Expected output

For each of the 64 output bytes the testbench prints its own encryption next to the DUT's, followed by `very nice!` on a match or `oops!` on a mismatch, and finally the original and encrypted messages:

```
original message  = _________`@``@@```@@@...
encrypted message = ...
```

All 64 lines reporting `very nice!` means the hardware matches the reference model.
