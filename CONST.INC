CR           EQU 0dh
LF           EQU 0ah
BKSP         EQU 08h
BELL         EQU 07h
SPACE        EQU 20h
DOT          EQU '.'
COLON        EQU ':'
QUIT         EQU 'Q'
CHEVRONL     EQU '<'
CHEVRONR     EQU '>'


BUFFER_MAX   EQU 128
PROMPT       EQU '\'
MAX_ROWS     EQU 25

MODE_READ    EQU 00h
MODE_WRITE   EQU 01h
MODE_FILEW   EQU 02h
MODE_FILER   EQU 03h
MODE_ERROR   EQU 04h
MODE_QUIT    EQU 05h

WR_BUF_SIZE  EQU 255

options RECORD clear:1,paging:1,help:1

