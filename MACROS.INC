; Print char
; destroys ah,dl
print MACRO CHAR
   mov dl,CHAR
   mov ah,02h
   int 21h
ENDM

; Print '$' terminated string
; destroys ax,dx
print_string MACRO SEGM,OFF
   push ds
   mov ax,SEGM
   mov ds,ax
   mov dx,OFF
   mov ah,09h
   int 21h
   pop ds
ENDM

; Print digit from byte
; destroys ah,dl
print_digit MACRO DIGIT
   mov dl,DIGIT
   add dl,30h
   mov ah,02h
   int 21h
ENDM

shiftr MACRO REG,NUM
REPT NUM
   shr REG,1
ENDM
ENDM

shiftl MACRO REG,NUM
REPT NUM
   shl REG,1
ENDM
ENDM

; Resizes allocated memory to 4k
resize_8k MACRO
   mov ah,4ah
   mov bx,200h                    ; 512 * 16 (paragraph size) 
   int 21h
ENDM

; Exit to DOS
; destroys ah
exit MACRO
   mov  ax,4c00h
   int  21h
ENDM              
