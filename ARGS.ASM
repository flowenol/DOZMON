.MODEL SMALL
.DATA

INCLUDE const.inc

PSP_ARGS_OFFSET EQU 80h

OPTION_PREFIX  EQU '/'
OPTION_CLS     EQU 'c'
OPTION_PAGING  EQU 'p'
OPTION_ADDMEM  EQU 'a'
OPTION_HELP    EQU 'h'

option options <0,0>
psp DW ?
addmem_pgs DW 0

PUBLIC option
PUBLIC psp
PUBLIC addmem_pgs

.CODE

set_option MACRO opt
   mov ah,option       
   or ah,MASK opt
   mov option,ah
ENDM

is_option_set MACRO opt
   mov ah,option
   and ah,MASK opt
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
   mov cl,es:[bx]                 ; load cl with argument chars number
   jcxz parse_end                 ; end if no chars

parse_loop:
   inc bx                         ; proceed with next char
   
   mov al,es:[bx]                 ; load char
   dec cl
   cmp al,OPTION_PREFIX           ; check if char indicates option start
   jne parse_check                ; if not check and proceed with next char

   call NEAR PTR parse_arg        ; if yes try to parse

   is_option_set invalid          ; if invalid option was detected
   jne parse_end                  ; end parsing

   jmp parse_next                 ; and proceed with next char

parse_check:
   cmp al,SPACE                   ; if char is space proceed with next char
   je parse_next

   set_option invalid             ; else flag invalid option
   jmp parse_end                  ; stop parsing   

parse_next:
   test cx,cx
   jnz parse_loop                 ; proceed until args chars exhausted
   
parse_end:
   pop es                         ; restore previous es
   retn
ENDP

; Helper function which tries to parse individual options
;
; destroys ax,bx,cl
parse_arg PROC NEAR
   jcxz parse_arg_end             ; return if no more chars left

   inc bx                         ; load next char
   mov al,es:[bx]
   dec cl               

   cmp al,OPTION_HELP             ; check if indicates help option
   jne cls

   set_option help
   jmp parse_arg_end

cls:
   cmp al,OPTION_CLS              ; check if indicates clear screen option
   jne pagng

   set_option clear
   jmp parse_arg_end

pagng:
   cmp al,OPTION_PAGING           ; check if indicates paging option
   jne addmemory

   set_option paging
   jmp parse_arg_end

addmemory:
   cmp al,OPTION_ADDMEM           ; check if indicates addmem option
   jne parse_arg_err

   set_option addmem

   ; look for the number of paragraphs
   ; parse into word addmem_pgs
   call NEAR PTR parse_addmem

   jmp parse_arg_end

parse_arg_err:
   set_option invalid             ; flag invalid option
   retn                           ; end parsing

parse_arg_end:
   retn
ENDP

; parses chars from PSP segment
; into addmem_pgs variable
; assumes:
; es:[bx] - chars
; cl - chars left
parse_addmem PROC NEAR
parse_addmem_start:
   jcxz parse_addmem_end          ; end if no chars left

   inc bx                         ; read char
   mov al,es:[bx]
   dec cl

   cmp al,SPACE                   ; check for whitespace chars
   jne parse_addmem_digits        ; if not whitespace then parse digits

   cmp addmem_pgs,0               ; if whitespace and addmem_pgs not set
   je parse_addmem_start          ; then skip

   jmp parse_addmem_end           ; if whitespace and addmem_pgs set
                                  ; then end parsing arg

parse_addmem_digits:
   cmp al,'0'                     ; error on non-numeric chars
   jl parse_addmem_err
   
   cmp al,'9'
   jg parse_addmem_err   

   sub al,30h                     ; convert to single digit value

   xor ah,ah                      ; clear ah
   push ax                        ; save parsed digit
   mov ax,addmem_pgs              ; load paragraphs
   mov dx,10                      ; multiply by 10
   mul dx
   test dx,dx                     ; if larger than 16 bit 
   jnz parse_addmem_err           ; then error
   pop dx                         ; restore parsed digit
   add ax,dx                      ; add to paragraphs
   mov addmem_pgs,ax              ; save new number of paragraphs

   jmp parse_addmem_start         ; try with next char

parse_addmem_err:
   set_option invalid
parse_addmem_end:
   retn
ENDP

END 
