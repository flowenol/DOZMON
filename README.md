# DOZMON 

**DOZMON** is an obsolete DOS memory monitor loosely based on a famous Apple-1 and Apple ][ monitor programs. It uses very similar syntax and offers additional bidirectional file-memory transfer functionality. The source is MASM compatible.

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

Show memory allocated by program:
```
\M
program start addr     = 0x15360h
program end addr       = 0x16360h
file buffer start addr = 0x16370h
file buffer end addr   = 0x1656fh
```

To quit program type `Q` or `Ctrl-C`
