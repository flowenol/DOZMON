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

byte_wr     DB 0                  ; current parsed byte in write mode
byte_flg    DB 0                  ; byte boudary flag in write mode

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

   cmp cl,1                       ; if input size is not equal to 1 then
   jne parse_input1               ; proceed with parsing

   mov al,ds:[si]                 ; load first typed char
   cmp al,QUIT                    ; check if char is Q
   jne parse_input1               ; if not proceed with parsing

   jmp quit_mode                  ; else quit mode is determined

parse_input1:
   cmp cl,0                       ; if input size is not equal 0 then try
   jne determine_mode             ; to determine mode

   jmp error_mode                 ; else error mode is determined

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Read mode                       ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
read_mode:
   dec cx                         ; decrement cx in case the mode was
                                  ; determined with DOT
   mov mode,MODE_READ             ; determine the mode to MODE_READ
 
   jcxz read_end

read_mode1:
   lodsb                          ; read next char into al

   call hex_char                  ; check if al is hex char
   jnz read_mode2                 ; if yes then proceed
   jmp error_mode                 ; if no then finish with error

read_mode2:
   call char_to_hex               ; convert hex char to digit
   mov bx,end_off                 ; load start_off value to bx
   mov dx,end_seg                 ; load start_seg value to dx

   shiftl4 al                     ; shl 4 less significants bits in al by 4
   rotatel4 al,bx,dx              ; shift 4 bits left in dx:bx:al

   mov end_off,bx                 ; store end segment & offset
   mov end_seg,dx

   loop read_mode1                ; loop until input buffer is exhausted

read_end:
   jmp all_parsed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Write mode                      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
write_mode:
   dec cx                         ; decrement cx due to detected colon char
   mov mode,MODE_WRITE            ; determine the mode to MODE_WRITE
   mov byte_wr,0                  ; clear actual byte variable
   mov byte_flg,0                 ; clear byte boundary detection flag

   jcxz write_end                 ; if there is no input to process then finish

write_mode1:
   lodsb                          ; load char from input

   call hex_char                  ; check if char is hex
   jnz write_mode4                ; if yes then parse byte 

   cmp al,SPACE                   ; check if char is SPACE
   jne write_mode2                ; if not then determine error mode
   cmp byte_flg,0                 ; check if this SPACE is a byte boundary
   je write_mode5                 ; if not then proceed to next char
   jmp write_mode3                ; if yes then finish and save the byte

write_mode2:
   jmp error_mode

write_mode3:                      
   xor bx,bx
   mov bl,bytes_len 
   mov di,bx                      ; load current parsed byte count into di
   mov bx,OFFSET bytes_wr         ; load bx with offset of parsed bytes array
   mov dl,byte_wr
   mov byte ptr [bx + di],dl      ; save parsed byte into bytes array

   mov byte_wr,0                  ; clear parsed byte
   mov byte_flg,0                 ; clear byte boundary helper flag
   inc bytes_len                  ; increment bytes count

   jmp write_mode5                ; jump to loop tail
  
write_mode4:
   shl byte_wr,1                  ; shift currently parsed byte left x4 times
   shl byte_wr,1
   shl byte_wr,1
   shl byte_wr,1
   call char_to_hex               ; convert char to hex value
   or byte_wr,al                  ; add lower 4 bits to curently parsed byte
   mov byte_flg,1                 ; set byte boundary helper flag

write_mode5:
   loop write_mode1               ; loop until input buffer is exhausted

   cmp byte_flg,1                 ; check if unfinished byte is pending
   jne write_end                  ; if not then finish

   xor bx,bx                      ; else save the byte in write buffer
   mov bl,bytes_len
   mov di,bx
   mov bx,OFFSET bytes_wr
   mov dl,byte_wr
   mov byte ptr [bx + di],dl

   inc bytes_len                  ; and increment bytes count

write_end:
   jmp all_parsed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Quit mode                       ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
quit_mode:
   mov mode,MODE_QUIT
   retn

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Error mode                      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
   jl digit                       ; if not jump to digit handling
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
   je hex_char_end
   cmp al,QUIT
hex_char_end:
   ret
ENDP

END 
