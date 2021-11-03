.MODEL SMALL
.DATA

INCLUDE const.inc

PSP_ARGS_OFFSET EQU 80h

OPTION_START   EQU '/'
OPTION_NOCLS   EQU 'n'
OPTION_HELP    EQU 'h'
OPTION_PAGING  EQU 'p'

option options <0,0>
psp DW ?

PUBLIC option
PUBLIC psp

.CODE

set_option MACRO opt
   mov ah,option       
   or ah,MASK opt
   mov option,ah
ENDM

PUBLIC parse_args

; Parses program args in search for valid options
;
; destroys ax,bx,cx
parse_args PROC NEAR
   push es                        ; save es
   mov es,psp                     ; set es to PSP segment
   mov bx,PSP_ARGS_OFFSET         ; set bx to args offset
  
   xor cx,cx                      ; clear cx
   mov cl,es:[bx]                 ; load cl argument chars number
   jcxz parse_end                 ; end if no chars

parse_loop:
   inc bx                         ; proceed with next char
   
   mov al,es:[bx]                 ; load char
   cmp al,OPTION_START            ; check if char indicates option start
   jne next                       ; if not proceed with next char

   call parse_arg                 ; if yes try to parse

next:
   loop parse_loop                ; proceed until args chars exhausted
   
parse_end:
   pop es                         ; restore previous es
   retn
ENDP

; Helper function which tries to parse individual options
;
; destroys ax,bx,cl
parse_arg PROC
   jcxz parse_arg_ret             ; return if no more chars left

parse:
   inc bx                         ; load next char
   mov al,es:[bx]               

   cmp al,OPTION_HELP             ; check if indicates help option
   jne nocls

   set_option help

nocls:
   cmp al,OPTION_NOCLS            ; check if indicates no clear screen option
   jne pagng

   set_option no_clear

pagng:
   cmp al,OPTION_PAGING           ; check if indicates paging option
   jne parse_arg_end

   set_option paging

parse_arg_end:
   dec cl                         ; adjust cl for read character
parse_arg_ret:
   ret
ENDP

END 
