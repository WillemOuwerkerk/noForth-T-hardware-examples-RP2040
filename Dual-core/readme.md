## Dual core usage

- [****Core-1.f****](Core-1.f) ; Contains the primitives for using the inter-core
  fifo, and code for starting code & stopping code on the second core
- [****blink-1.f****](blink-1.f) ; Simple flasher that may run on the second core
- [****Dual-core-demos.f****](Dual-core-demos.f) ; Test code for nForth t duo, the
the programs do inter-core communication using the fifo's
