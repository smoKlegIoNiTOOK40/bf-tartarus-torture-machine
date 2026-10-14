# Third-party interpreter

Tartarus executes handwritten BF using the ordinary, unmodified Windows
`qdb.exe` distributed by **Daniel B. Cristofani**:

- Author's page: https://www.brainfuck.org/
- Original Windows distribution: https://www.brainfuck.org/qdb.zip
- Original author readme: [third-party/qdb/readme.txt](third-party/qdb/readme.txt)
- SHA-256: `C2589DADC81EB910D53D08AC90A6DDF1ED39D6C44958AA17C9FB180358F42595`

The executable was downloaded on 8 October 2026. It has not been modified
or rebuilt for Tartarus. The author documents Windows text-mode I/O and EOF
leaving the cell unchanged. Our byte-safe BF protocol accommodates that
behavior. Model arithmetic is BF interpreted by qdb; qdb contains no
Tartarus-specific prediction, training or verification code.

The original readme is preserved with the downloadable release packages.
Attribution to this interpreter is separate from authorship of Tartarus.
