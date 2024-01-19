# DOZMON

**DOZMON** is an obsolete DOS memory monitor loosely based on the famous Apple-1 and Apple ][ monitor programs. It uses very similar syntax and offers additional bidirectional file-memory transfer functionality. It also allows to read and write IO port addresses. The source is MASM compatible.

## Requirements

You need DOS 3.0+ environment and TASM assembler 2.0+ to compile the sources.

## Options

- `/h` - display help
- `/p` - enable paging
- `/c` - clear screen

## Usage

Read single memory address at $FFFFF:

```
\FFFFF
FFFFF: 00                                                   .
```

Read memory range at $FFFFE-$FFFFF:
```
\FFFFE.FFFFF
FFFFE: 00 00                                                ..
```

Write 2 bytes into memory starting at address $FFFFE:
```
\FFFFE: 11 22
```

Write memory range into file:
```
\>00000.0FFFF
enter file name: memory.bin
```

Write file contents into memory starting at address $00000:
```
\<00000
enter file name: memory.bin
file size: 65536
```

Write byte to IO port at address $70:
```
\!70: 04
```

Read bytes from IO port at address $71:
```
\!71
0071: 23 23
```

Show memory allocated by program:
```
\M
program start addr     = 0x15360h
program end addr       = 0x1635fh
file buffer start addr = 0x16370h
file buffer end addr   = 0x1656fh
stack end addr         = 0x16360h
stack start addr       = 0x16560h
```

To quit program type `Q` or `Ctrl-C`
