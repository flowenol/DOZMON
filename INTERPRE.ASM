.MODEL SMALL
.DATA

INCLUDE const.inc

EXTRN input:BYTE:BUFFER_MAX
EXTRN input_size:BYTE

EXTRN start_off:WORD
EXTRN start_seg:WORD
EXTRN end_off:WORD
EXTRN end_seg:WORD
EXTRN mode:BYTE
EXTRN bytes_wr:BYTE:BUFFER_MAX
EXTRN bytes_len:BYTE

.CODE

; Shifts REG by 4 positions left
shiftl4 MACRO REG
REPT 4
  shl REG,1
ENDM
ENDM

; Shifts SOURCE left by 1 position,
; shifts left rotates carry into DEST1,
; shifts left rotates carry from DEST1 to DEST2
; 4 times
rotatel4 MACRO SOURCE,DEST1,DEST2
REPT 4
   shl SOURCE,1                       
   rcl DEST1,1
   rcl DEST2,1
ENDM
ENDM

PUBLIC parse_input

; Parses input buffer and sets mode
; and according segments with offsets
;
; destroys cx,bx,al,si
parse_input PROC NEAR
   mov si,OFFSET input            ; point si to beginning of input
   xor cx,cx                      ; clear counter
   mov cl,input_size              ; put input buffer size into cl

determine_mode:
   lodsb                          ; load first char

   cmp al,DOT                     ; if the char is dot then read mode is
   je read_mode                   ; determined

   cmp al,COLON                   ; if the char is colon then write mode is
   jne determine_mode1            ; determined
   jmp write_mode

determine_mode1:
   call hex_char                  ; if the char is not hex char at this moment
   jnz determine_mode2            ; then error mode is determined
   jmp error_mode

determine_mode2:
   call char_to_hex               ; convert hex char to digit
   mov bx,start_off               ; load start_off value to bx
   mov dx,start_seg               ; load start_seg value to dx

   shiftl4 al                     ; shl 4 less significants bits in al by 4
   rotatel4 al,bx,dx              ; shift 4 bits left in dx:bx:al

   mov start_off,bx               ; store start segment & offset
   mov start_seg,dx

   loop determine_mode            ; loop until end reached
   inc cx                         ; if end was reached then we must increment
                                  ; cx by 1 to counter the decrement in
                                  ; read_mode label

read_mode:
   dec cx                         ; decrement cx in case the mode was
                                  ; determined with DOT
   mov mode,MODE_READ             ; determine the mode to MODE_READ
 
   jcxz all_parsed

read_end:
   lodsb                          ; read next char into al

   call hex_char                  ; check if al is hex char
   jz error_mode                  ; if no then finish with error

   call char_to_hex               ; convert hex char to digit
   mov bx,end_off                 ; load start_off value to bx
   mov dx,end_seg                 ; load start_seg value to dx

   shiftl4 al                     ; shl 4 less significants bits in al by 4
   rotatel4 al,bx,dx              ; shift 4 bits left in dx:bx:al

   mov end_off,bx                 ; store end segment & offset
   mov end_seg,dx

   loop read_end
   
   jmp all_parsed

write_mode:


error_mode:
   mov mode,MODE_ERROR
   retn

all_parsed:
   mov cl,12                      ; adjust segment variables by shifting
   shl start_seg,cl               ; 12 positions left
   shl end_seg,cl

   retn
ENDP

; Changes hex char in al to number
;
; destroys al
char_to_hex PROC
   cmp al,60h                     ; check if char in al is alphanumeric
   jl digit                       ; if not jump to corresponding lael
   sub al,60h                     ; subtract char before 'a'
   add al,09h                     ; add 9 to adjust value
   jmp converted
digit:
   sub al,30h                     ; subtract '0' to get number
converted:
   ret
ENDP

; Checks if al contains hex char
; Z=1 if not, 0 otherwise
;
; destroys nothing
hex_char PROC
   cmp al,DOT
   je hex_char_end
   cmp al,COLON
   je hex_char_end
   cmp al,BKSP
   je hex_char_end
   cmp al,SPACE
hex_char_end:
   ret
ENDP

END 
