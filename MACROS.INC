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

; Resizes allocated memory to 4k
resize_4k MACRO
   mov ah,4ah
   mov bx,100h                    ; 256 * 16 (paragraph size) 
   int 21h
ENDM

; Exit to DOS
; destroys ah
exit MACRO
   mov  ax,4c00h
   int  21h
ENDM              
