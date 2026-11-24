# ML-KEM NTT accelerator – Kria K24C (xck24-ubva530-2LV-c)
- `rtl/` (VHDL-2008) butterfly (Montgomery, QINV=-3327, bit-exact w/ ref), 2-bank BRAM core (1 butterfly/cycle, ~940 cycles/NTT), AXI4-Lite wrapper, zeta ROM (generated from ref `zetas[]`).
- `ref/` `make vectors` clones pq-crystals/kyber, builds ref `ntt()`+`poly_reduce` vectors (64 incl. corner cases). Vectors included.
- `tb/` core + AXI testbenches (self-checking). Quick sim (ghdl): compile rtl in order ntt_ram, ntt_butterfly, zeta_rom, ntt_core, ntt_axi, then tb; `ghdl -r --std=08 tb_ntt_core -gVEC_DIR=ref` (xsim uses the default relative path)
- `scripts/build.tcl` full flow: project, PS+SmartConnect BD, xsim, impl, bitstream, XSA.
- `sw/ntt_hw_test.c` on-board check. Regs @0xA0000000: 0x0 CTRL(start), 0x4 STATUS(busy,done), 0x400+4i coeff i.
Results are Barrett-reduced on read (= ref ntt + poly_reduce). Verified: ghdl 64/64 vectors + AXI test PASS.
