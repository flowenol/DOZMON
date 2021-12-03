.MODEL SMALL
.DATA

INCLUDE const.inc

allowed_chars DB '0123456789'
              DB 'abcdef'
              DB QUIT
              DB CR,BKSP,SPACE
              DB DOT,COLON,CHEVRONL,CHEVRONR
ALLOWED_CHARS_LENGTH EQU ($ - allowed_chars)

.CODE

INCLUDE macros.inc

PUBLIC read_str
PUBLIC wait_for_char
PUBLIC read_char
PUBLIC print_number
PUBLIC cls
PUBLIC print_address
PUBLIC print_hex
PUBLIC print_at_col
PUBLIC div_by_10

; Reads from standard input a string of max si 
; length into es:di
;
; destroys cx,ax,di
read_str PROC NEAR
   mov cx,si                      ; ensure max si characters in string
   cld                            ; ensure incrementing di for stosb

read_str_char:
   mov ah,08h                     ; read char into al
   int 21h

   cmp al,BKSP                    ; check if the character is backspace
   jne read_str_nobksp            ; if no handle normal character

   cmp cx,si                      ; else check if not first character
   je read_str_char               ; if first char just read next char

   inc cx                         ; else fix cx and di
   dec di

   mov byte ptr es:[di],0         ; clear the corresponding character in buffer

   print BKSP                     ; and print backspace
   print SPACE
   print BKSP
   
   jmp read_str_char              ; then read next char

read_str_nobksp:

   print al                       ; print the char

   stosb                          ; store the char in destination buffer

   cmp al,CR                      ; terminate if char is CR
   loopne read_str_char           ; or the buffer is depleted

   retn
ENDP

; Loops until char declared in al is
; read from keyboard
;
; destroys ah,bx
wait_for_char PROC NEAR
   push ax

wait_for:
   mov ah,08h                     ; read char into al
   int 21h

   mov bx,sp
   cmp al,ss:[bx]
   jne wait_for

   pop ax
   retn
ENDP

; Reads only allowed chars
; destroys ax,es,di,dl,cx
;
; returns char in al 
read_char PROC NEAR
   mov ax,@data                   ; load data segment to es regiser
   mov es,ax

   cld                            ; ensure incrementing di for scasb

read:
   mov di,OFFSET allowed_chars    ; load allowed chars offset to di
   mov cx,ALLOWED_CHARS_LENGTH    ; initialize counter

   mov ah,08h                     ; read char into al
   int 21h

read_loop:
   scasb                          ; scan for char in al
   je found                       ; if found then return
   loop read_loop   

   print BELL                     ; print bell on not allowed char
   jmp read                       ; if not allowed read again

found:
   retn
ENDP

; Prints unsigned 32 bit integer number 
; from bytes on stack
;
; destroys: ax, bx, cx, dx, si
print_number PROC NEAR
   push bp                        ; set stack frame with 11 bytes for
   mov bp,sp                      ; number string variable
   sub sp,11
   mov byte ptr [bp - 1],'$'      ; put string termination at highest byte
   mov si,0 
   
   sub sp,5                       ; reserve 5 bytes on stack for number and
   mov bx,sp                      ; remainder
   mov ax,[bp + 4]                ; copy argument for dicision
   mov word ptr ss:[bx + 1],ax
   mov ax,[bp + 6]
   mov word ptr ss:[bx + 3],ax

calc_digit:
   call NEAR PTR div_by_10        ; divide with remainder
   mov bx,sp
   mov al,ss:[bx]                 ; convert remainder to ASCII digit
   add al,30h
   dec si                         ; decrement digit index in string
   mov byte ptr [bp + si - 1],al  ; store ASCII digit in string
   
   mov ax,word ptr ss:[bx + 1]    ; check if quotient is 0
   or ax,word ptr ss:[bx + 3]

   jnz calc_digit                 ; if not repeat division

   mov bx,ss                      ; get stack segment for string print
   lea dx,[bp + si - 1]           ; get effective offset for string beginning
   print_string bx,dx             ; and print string

   add sp,5                       ; restore stack: 5 bytes for quotient and r
   add sp,11                      ; restore stack: 11 bytes for number string
   pop bp
   retn
ENDP

; Clears screen and positions
; the cursor in home position (0,0)
;
; destroys ax,dx,cx,bh
cls PROC NEAR
   mov dl,79                      ; dl,dh = x,y of right corner of window
   mov dh,24 
   mov cx,0                       ; cl,ch = x,y of upper left corner of window
   mov bh,07h                     ; display attribute to use
  
   mov ah,06h                     ; scroll or initialize window function
   mov al,0                       ; zero lines to scroll
   int 10h                        ; call ROM BIOS video driver

   mov dx,0                       ; set cursor position in dx to 0,0
   mov bh,0                       ; set page 0
   mov ah,2                       ; select cursor position function
   int 10h                        ; call ROM BIOS video driver
   retn
ENDP

; Prints real address in es:di
;
; destroys ax,cl
print_address PROC NEAR
   push bp                        ; save bp
   mov bp,sp                      ; set new stack frame
   sub sp,3                       ; reserve 3 bytes on stack for real address
                                  ; calculation

   mov ax,es                      ; move segment register to ax
   shl ax,1                       ; rotate MSBit in ax into the highest
   rcl byte ptr [bp - 1],1        ; byte on stack frame, 4x times

   shl ax,1   
   rcl byte ptr [bp - 1],1

   shl ax,1   
   rcl byte ptr [bp - 1],1

   shl ax,1   
   rcl byte ptr [bp - 1],1

   add ax,di                      ; sum shifted segment and offset
   adc byte ptr [bp - 1],0        ; add carry to highest byte on stack frame

   mov word ptr [bp - 3],ax       ; save sum (4 address nibbles) on stack frame
   
   mov al,[bp - 1]                ; print MSB nibble of real address
   call print_nibble              ; from highest byte on stack frame

   mov cl,12                      ; set cl for 12 right shifts

print_nibbles:
   mov ax,word ptr [bp - 3]       ; set ax to remaining nibbles
   shr ax,cl                      ; shift right to get next nibble in al
   call print_nibble             
   sub cl,4                       ; decrement cl by nibble length
   jns print_nibbles              ; branch till cl becomes negative

   add sp,3                       ; restore original stack frame
   pop bp
   retn
ENDP

; Prints byte in al
;
; destroys bx
print_hex PROC NEAR
   push cx                        ; preserve cx
   push ax                        ; preserve ax
   mov cl,4                       
   shr al,cl                      ; shr 4 times to get high nibble
   call print_nibble              ; print high nibble
   mov bx,sp
   mov ax,ss:[bx]                 ; restore ax without popping from stack
   call print_nibble              ; print low nibble
   pop ax                         ; restore ax
   pop cx                         ; restore cx
   retn
ENDP

; Prints charcter in al at column in ah
; int the same row, and then returns to
; the previous column
;
; destroys ah,bh,dx
print_at_col PROC NEAR
   push cx                        ; save cx
   push bp                        ; save current stack frame
   mov bp,sp                      ; set new stack frame
   sub sp,1                       ; reserve 1 byte on stack for current column

   mov bh,00h                     ; set page 0  

   push ax                        ; save column parameter in ah
   mov ah,03h                     ; read current cursor position into dh:dl 
   int 10h

   mov [bp - 1],dl                ; save original cursor column
                                  ; note: original row still in dh
 
   pop ax                         ; restore column parameter in ah
   mov dl,ah                      ; set destination column in dl
   mov ah,02h                     ; set cursor position at destination column
   int 10h

   cmp al,SPACE
   jb print_dot

   cmp al,7eh
   ja print_dot

   print al
   jmp restore_col

print_dot:
   print DOT  

restore_col:
   mov dl,[bp - 1]                ; set column to the original
   mov ah,02h                     ; set cursor position at original column
   int 10h
  

   add sp,1                       ; destroy local variable
   pop bp                         ; restore stack frame pointer
   pop cx                         ; restore cx
   retn
ENDP

; Prints lower nibble in al
;
; destroys al
print_nibble PROC
   and al,0Fh
   cmp al,9
   jg hex_nibble
   add al,30h
   print al
   ret

hex_nibble:
   add al,57h
   print al
   ret
ENDP

div_by_10 PROC NEAR
   push bp                        ; preserve frame pointer
   mov bp,sp
   sub sp,8                       ; reserve 8 bytes on stack for quotient
   mov bx,sp                      ; and remainder

   xor ax,ax                      ; r = q = 0
   mov word ptr ss:[bx],ax        ; q 
   mov word ptr ss:[bx + 2],ax    ; q + 2
   mov word ptr ss:[bx + 4],ax    ; r
   mov word ptr ss:[bx + 6],ax    ; r + 2

   mov cx,8                       ; i = 31
div_loop1:
   dec cl

   shl byte ptr ss:[bx + 4],1     ; r <<= 1
   rcl byte ptr ss:[bx + 5],1
   rcl byte ptr ss:[bx + 6],1
   rcl byte ptr ss:[bx + 7],1

   mov ax,1                       ; 1 << i
   shl ax,cl

   mov dl,[bp + 8]                ; n & (1 << i)
   and dl,al
   jz zero1

   or byte ptr ss:[bx + 4],1      ; r |= n & (1 << i) > ? 1 : 0
   
zero1:
   mov al,ss:[bx + 4]             ; r > d ?
   cmp al,10
   jge larger1

   xor al,al
   or al,ss:[bx + 5]
   or al,ss:[bx + 6]
   or al,ss:[bx + 7]
   jz div_loop_end1

larger1:
   mov ax,1                       ; q |= 1 << i
   shl ax,cl
   or ss:[bx + 3],al 

   mov ax,10                      ; r = r - 10
   sub word ptr ss:[bx + 4],ax
   sbb word ptr ss:[bx + 6],0
   
div_loop_end1:
   inc cl
   loop div_loop1

   mov cx,8
div_loop2:
   dec cl

   shl byte ptr ss:[bx + 4],1
   rcl byte ptr ss:[bx + 5],1
   rcl byte ptr ss:[bx + 6],1
   rcl byte ptr ss:[bx + 7],1

   mov ax,1
   shl ax,cl

   mov dl,[bp + 7]
   and dl,al
   jz zero2

   or byte ptr ss:[bx + 4],1
   
zero2:
   mov al,ss:[bx + 4]
   cmp al,10
   jge larger2

   xor al,al
   or al,ss:[bx + 5]
   or al,ss:[bx + 6]
   or al,ss:[bx + 7]
   jz div_loop_end2

larger2:
   mov ax,1                       ; q |= 1 << i
   shl ax,cl
   or ss:[bx + 2],al 

   mov ax,10                      ; r = r - 10
   sub word ptr ss:[bx + 4],ax
   sbb word ptr ss:[bx + 6],0
   
div_loop_end2:
   inc cl
   loop div_loop2

   mov cx,8
div_loop3:
   dec cl

   shl byte ptr ss:[bx + 4],1
   rcl byte ptr ss:[bx + 5],1
   rcl byte ptr ss:[bx + 6],1
   rcl byte ptr ss:[bx + 7],1

   mov ax,1
   shl ax,cl

   mov dl,[bp + 6]
   and dl,al
   jz zero3

   or byte ptr ss:[bx + 4],1
   
zero3:
   mov al,ss:[bx + 4]
   cmp al,10
   jge larger3

   xor al,al
   or al,ss:[bx + 5]
   or al,ss:[bx + 6]
   or al,ss:[bx + 7]
   jz div_loop_end3

larger3:
   mov ax,1                       ; q |= 1 << i
   shl ax,cl   
   or ss:[bx + 1],al 

   mov ax,10                      ; r = r - 10
   sub word ptr ss:[bx + 4],ax
   sbb word ptr ss:[bx + 6],0
   
div_loop_end3:   
   inc cl
   loop div_loop3

   mov cx,8
div_loop4:
   dec cl

   shl byte ptr ss:[bx + 4],1
   rcl byte ptr ss:[bx + 5],1
   rcl byte ptr ss:[bx + 6],1
   rcl byte ptr ss:[bx + 7],1

   mov ax,1
   shl ax,cl

   mov dl,[bp + 5]
   and dl,al
   jz zero4

   or byte ptr ss:[bx + 4],1
   
zero4:
   mov al,ss:[bx + 4]
   cmp al,10
   jge larger4

   xor al,al
   or al,ss:[bx + 5]
   or al,ss:[bx + 6]
   or al,ss:[bx + 7]
   jz div_loop_end4

larger4:
   mov ax,1                       ; q |= 1 << i
   shl ax,cl
   or ss:[bx],al 

   mov ax,10                      ; r = r - 10
   sub word ptr ss:[bx + 4],ax
   sbb word ptr ss:[bx + 6],0
   
div_loop_end4:   
   inc cl
   loop div_loop4


   mov al,ss:[bx + 4]             ; r
   mov byte ptr ss:[bp + 4],al    ; result r

   mov ax,ss:[bx]                 ; q
   mov word ptr ss:[bp + 5],ax    ; result q

   mov ax,ss:[bx + 2]             ; q + 2
   mov word ptr ss:[bp + 7],ax    ; result q + 2

   add sp,8                       ; restore previous stack frame
   pop bp   
   retn
ENDP

END