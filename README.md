# Quest BBC Micro source reconstruction

This repository contains a complete, byte-exact BeebAsm reconstruction of the
BBC Micro `$.QUEST1` program payload. All executable code, tables, text,
graphics, player sprites, enemy sprites, room data, and other payload bytes are
declared in the two maintained source files:

- `source_bbc/quest1.asm`
- `source_bbc/memory_map.inc`

The assembly does not include binary fragments and does not require an
original disk image or an authority payload to build.

## Requirements

- PowerShell 7 or Windows PowerShell 5.1
- [BeebAsm](https://github.com/stardot/beebasm), either on `PATH` or supplied
  with `-BeebAsm`

## Build

From the repository root:

```powershell
./build.ps1
```

Or specify the assembler explicitly:

```powershell
./build.ps1 -BeebAsm C:\path\to\beebasm.exe
```

The build writes `build/reconstruction/QUEST1` and
`build/reconstruction/quest1.labels`.

## Validate

```powershell
./validate.ps1
```

Validation performs a clean source assembly and requires the resulting payload
to be exactly `$3F20` bytes with SHA-256
`d83eadf906c83a1b1244f4ed85f34147c754ffa1ac5528738cb967185bcb528b`.
That digest is the byte-exact authority established by the reverse-engineering
project, so validation needs no copyrighted original media.

## Layout and provenance

The DFS payload loads at `$1D00`, executes at `$5C11`, and internally relocates
substantial code and data. The source preserves those addresses and uses
`COPYBLOCK`/`CLEAR` deliberately to reproduce the transport and runtime layout.
`source_bbc/reconstruction.json` records the evidence level and original address
range for each reconstructed routine and data block.

Some source comments cite evidence artifacts and optional variant tools from
the larger private analysis workspace. Those citations document how names and
behavior were established; none of those files is a build or validation
dependency of this standalone repository.

The original game and its assets remain the property of their respective
copyright holders. No original disk image is included here.
