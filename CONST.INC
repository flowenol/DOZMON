CR         EQU 0dh
LF         EQU 0ah
BKSP       EQU 08h
BELL       EQU 07h
SPACE      EQU 20h
DOT        EQU '.'
COLON      EQU ':'
QUIT       EQU 'Q'

BUFFER_MAX EQU 128
PROMPT     EQU '\'
MAX_ROWS   EQU 25

MODE_READ  EQU 00h
MODE_WRITE EQU 01h
MODE_ERROR EQU 02h
MODE_QUIT  EQU 03h

options RECORD clear:1,paging:1,help:1

