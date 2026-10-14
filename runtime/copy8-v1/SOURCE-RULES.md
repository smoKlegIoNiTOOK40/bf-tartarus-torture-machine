# Source rules: handwritten BF and byte-preserving assembly

New BF modules may be written by hand. Existing handwritten BF source may be
edited by hand. The assembly restriction does not limit development to copying.

All model and teacher arithmetic, training, inference, loss, logits, argmax,
selection and independent numerical verification must execute as Brainfuck.
No host-side model arithmetic, BLAS or external model runtime.
No BF command generation from templates, macros, formulas or other languages.

Python, CMD or other host tools may automate assembly solely by exact binary
copying and concatenation of ready, manually written BF fragments.
No bytes may be stripped, reformatted, substituted or added by the assembler.
Write or edit fragments manually before assembly; preserve previous versions.
Record module ordering and boundary contracts; execute BF checks of pointer
and tape states at every boundary. A declaration alone is not a check.
Source-byte comparisons, hashes, file sizes and routing metadata may be handled
by host tools; these are not model arithmetic.
Keep original fragments and assembly reproducible.
Prior numerical and publication restrictions remain.

Production and diagnostic fragments have separate boundary contracts.
A test probe may deliberately change scratch cells, provided those changes
and its final pointer are documented. A bad join must fail the BF check.
