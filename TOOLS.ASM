.MODEL SMALL
.DATA

INCLUDE const.inc

allowed_chars DB '0123456789'
              DB 'abcdef'
              DB QUIT
              DB CR,BKSP,SPACE
              DB DOT,COLON
ALLOWED_CHARS_LENGTH EQU ($ - allowed_chars)

.CODE

INCLUDE macros.inc

PUBLIC wait_for_char
PUBLIC read_char
PUBLIC print_number
PUBLIC cls
PUBLIC print_address
PUBLIC print_hex
PUBLIC print_at_col

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

; Prints unsigned integer number 
; from byte in al
;
; destroys: ax, dx, si
print_number PROC NEAR
   push bp                        ; set stack frame with 4 bytes for local
   mov bp,sp                      ; string variable
   sub sp,4
   mov byte ptr [bp - 1],'$'      ; write "$" to highest byte in stack frame

   mov si,1                       ; initialize si with 1 (si goes negative)

divide_by_10:
   mov dl,10                       
   xor ah,ah                      ; clear highest byte in ax
   div dl                         ; divide ax by 10
   dec si                          
   mov [bp + si - 2],ah           ; put remainder to next byte in stack frame
   add byte ptr [bp + si - 2],30h ; convert to char
   cmp al,0                       ; finish if al == 0
   jne divide_by_10

   push ss                        ; copy ss to bx - segment parameter for
   pop bx                         ; dos print string function
   lea dx,[bp - si - 2]           ; load lowest assigned byte offset to dx
   print_string bx,dx             ; print string

   add sp,4                       ; restore previous frame and stack
   pop bp
   retn
ENDP

; Clears screen and positions
; the cursor in home position (0,0)
;
; destroys ax,dx,cx,bh
cls PROC NEAR
   mov dl,79                       ; dl,dh = x,y of right corner of window
   mov dh,24 
   mov cx,0                        ; cl,ch = x,y of upper left corner of window
   mov bh,07h                      ; display attribute to use
  
   mov ah,06h                      ; scroll or initialize window function
   mov al,0                        ; zero lines to scroll
   int 10h                         ; call ROM BIOS video driver

   mov dx,0                        ; set cursor position in dx to 0,0
   mov bh,0                        ; set page 0
   mov ah,2                        ; select cursor position function
   int 10h                         ; call ROM BIOS video driver
   retn
ENDP

; Prints real address in es:di
;
; destroys ax,cl
print_address PROC NEAR
   push bp                         ; save bp
   mov bp,sp                       ; set new stack frame
   sub sp,3                        ; reserve 3 bytes on stack for real address
                                   ; calculation

   mov ax,es                       ; move segment register to ax
   shl ax,1                        ; rotate MSBit in ax into the highest
   rcl byte ptr [bp - 1],1         ; byte on stack frame, 4x times

   shl ax,1   
   rcl byte ptr [bp - 1],1

   shl ax,1   
   rcl byte ptr [bp - 1],1

   shl ax,1   
   rcl byte ptr [bp - 1],1

   add ax,di                       ; sum shifted segment and offset
   adc byte ptr [bp - 1],0         ; add carry to highest byte on stack frame

   mov word ptr [bp - 3],ax        ; save sum (4 address nibbles) on stack frame
   
   mov al,[bp - 1]                 ; print MSB nibble of real address
   call print_nibble               ; from highest byte on stack frame

   mov cl,12                       ; set cl for 12 right shifts

print_nibbles:
   mov ax,word ptr [bp - 3]        ; set ax to remaining nibbles
   shr ax,cl                       ; shift right to get next nibble in al
   call print_nibble             
   sub cl,4                        ; decrement cl by nibble length
   jns print_nibbles               ; branch till cl becomes negative

   add sp,3                        ; restore original stack frame
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
  push cx                         ; save cx
  push bp                         ; save current stack frame
  mov bp,sp                       ; set new stack frame
  sub sp,1                        ; reserve 1 byte on stack for current column

  mov bh,00h                      ; set page 0  

  push ax                         ; save column parameter in ah
  mov ah,03h                      ; read current cursor position into dh:dl 
  int 10h

  mov [bp - 1],dl                 ; save original cursor column
                                  ; note: original row still in dh
 
  pop ax                          ; restore column parameter in ah
  mov dl,ah                       ; set destination column in dl
  mov ah,02h                      ; set cursor position at destination column
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
  mov dl,[bp - 1]                 ; set column to the original
  mov ah,02h                      ; set cursor position at original column
  int 10h
  

  add sp,1                        ; destroy local variable
  pop bp                          ; restore stack frame pointer
  pop cx                          ; restore cx
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


END
