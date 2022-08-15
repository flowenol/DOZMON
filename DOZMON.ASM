DOSSEG
.MODEL SMALL
.STACK 200h
.DATA

INCLUDE const.inc

input              DB BUFFER_MAX DUP(0)
input_size         DB 0

start_off          DW 0
start_seg          DW 0
end_off            DW 0
end_seg            DW 0
mode               DB 0
bytes_wr           DB BUFFER_MAX DUP(0)
bytes_len          DB 0

END_OF_STATE       EQU ($ - input)

help_string        DB CR,LF,"DOZMON ver 0.1 by flowenol",CR,LF
                   DB CR,LF
                   DB "Options:",CR,LF
                   DB "/c - enable clear screen",CR,LF
                   DB "/p - enable paging",CR,LF
                   DB "/h - display help",CR,LF
                   DB CR,LF,'$'

resize_err_string  DB CR,LF
                   DB "memory resize error = "
                   DB '$'

f_buf_err_string   DB CR,LF
                   DB "memory allocation error = "
                   DB '$'

file_err_string    DB CR,LF
                   DB "file access error"
                   DB '$'

EXTRN option:options              ; declared in 'args' module
EXTRN psp:WORD                    ; declared in 'args' module

GLOBAL input:BYTE:BUFFER_MAX
GLOBAL input_size:BYTE

GLOBAL start_off:WORD
GLOBAL start_seg:WORD
GLOBAL end_off:WORD
GLOBAL end_seg:WORD
GLOBAL mode:BYTE
GLOBAL bytes_wr:BYTE:BUFFER_MAX
GLOBAL bytes_len:BYTE

EXTRN file_buf:BYTE               ; declared in 'file' module
EXTRN file_mem_buf:WORD           ; declared in 'file' module

.CODE

INCLUDE macros.inc 

EXTRN parse_args:NEAR             ; declared in 'args' module

EXTRN wait_for_char:NEAR          ; declared in 'tools' module
EXTRN read_char:NEAR              ; declared in 'tools' module
EXTRN print_number:NEAR           ; declared in 'tools' module
EXTRN print_hex:NEAR              ; declared in 'tools' module
EXTRN cls:NEAR                    ; declared in 'tools' module
EXTRN print_address:NEAR          ; declared in 'tools' module
EXTRN print_at_col:NEAR           ; declared in 'tools' module
EXTRN alloc_mem:NEAR              ; declared in 'tools' module
EXTRN free_mem:NEAR               ; declared in 'tools' module

EXTRN parse_input:NEAR            ; declared in 'interpre' module

EXTRN open_file:NEAR              ; declared in 'file' module
EXTRN create_file:NEAR            ; declared in 'file' module
EXTRN read_from_file:NEAR         ; declared in 'file' module
EXTRN write_to_file:NEAR          ; declared in 'file' module
EXTRN close_file:NEAR             ; declared in 'file' module

main:

   resize_16k
   jnc start0

   jmp resize_error

start0:
   mov ax,@data
   mov ds,ax                      ; set DS to point to the data segment
   mov psp,es                     ; preserve PSP segment
   mov es,ax                      ; set ES to point to the data segment 

   call NEAR PTR parse_args       ; parse program arguments

   mov al,option                  ; check if help option was selected
   and al,MASK help
   jz start1                      ; proceed if no

   mov bx,OFFSET help_string      ; if yes then print help
   print_string @data,bx

   jmp finish                     ; end program if help option was selected

start1:
   mov al,option                  ; check if clear screen option was selected
   and al,MASK clear
   jz start2                      ; proceed if no

   call NEAR PTR cls              ; clear screen

start2:
   mov bx,F_BUF_PARS              ; allocate memory for file ops buffer
   call NEAR PTR alloc_mem
   jnc start3

   jmp alloc_error

start3:
   mov file_mem_buf,ax            ; save allocated file ops segment

start4:
   print PROMPT

   mov di,OFFSET input            ; reset input buffer
   mov cl,BUFFER_MAX

read:
   push cx                        ; save cl and di before call
   push di                 
   call NEAR PTR read_char        ; get char in al
   pop di                         ; restore di and cl
   pop cx

   cmp al,CR                      ; check if enter was pressed
   je read_loop                   ; and skip store in es:di

   cmp al,BKSP                    ; check if backspace pressed
   jne store_read                 ; proceed to store if not

   cmp di,OFFSET input            ; if di == 0 then we cannot delete
                                  ; more characters
   je cant_del                    ; and we need to fix cl by 1
                                  ; else we must decrement both di and cl
   print BKSP
   print SPACE
   print BKSP
   dec di                         ; decrement di
   inc cl                         ; increment cl twice
cant_del:
   inc cl                         ; increment cl once

   jmp read_loop                  ; do not store backspace
   
store_read:  
   print al                       ; print before saving
   stosb                          ; store char in buffer

read_loop:
   cmp al,CR                      ; check if enter pressed
   loopne read                    ; repeat until buffer exhausted or 
                                  ; enter pressed

   mov al,BUFFER_MAX              ; calcluate buffer size
   sub al,cl
   cmp al,BUFFER_MAX              ; in case of full buffer skip al adjustment
   je save_size
   dec al                         ; loopne always decrements so we must adjust
                                  ; value in al
save_size:
   mov input_size,al              ; save input buffer size
    
parse:
   call NEAR PTR parse_input      ; parse input to determine mode

   mov bx,OFFSET action_table     ; set bx to action table offset
   xor ah,ah                      ; clear ah
   mov al,mode                    ; put deduced mode in al
   mov di,ax                      ; copy ax to di
   shl di,1                       ; multiply di by 2 to get action table index

   jmp cs:[bx + di]               ; jump to label according to index

action_table:
   DW OFFSET print_action
   DW OFFSET write_action
   DW OFFSET filew_action
   DW OFFSET filer_action
   DW OFFSET error_action
   DW OFFSET finish


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Print action                    ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print_action:
   call compare_offsets           ; validate offsets
   jnc print_bytes

   jmp error_action

print_bytes:
   push es                        ; save original es segment value
   les di,[dword ptr start_off]   ; load start_off value into es:di 
   mov dh,MAX_ROWS + 1            ; set row counter to 26 (max+1)

print_offset:
   dec dh                         ; decrement row counter
   jnz print_offset1              ; if not last row then proceed 

   mov al,option                  ; check if paging option was set
   and al,MASK paging
   jz print_offset1               ; if paging not set then proceed

   mov al,CR                      ; wait for user to press CR
   call NEAR PTR wait_for_char
   mov dh,MAX_ROWS                ; and reset the row counter to max

   mov al,option                  ; check if clear screen option was set
   and al,MASK clear
   jz print_offset1

   call NEAR PTR cls              ; if yes clear the screen
   mov dh,MAX_ROWS                ; and reset the row counter to max

   jmp print_offset2              ; skip line feed after screen was cleared

print_offset1:
   print CR                       ; go to new line
   print LF
print_offset2:
   call NEAR PTR print_address    ; print current address in es:di
   print COLON                    ; followed by a colon

   mov cl,BYTES_ROW               ; print 16 bytes per line

print_byte:
   print SPACE
   mov al,es:[byte ptr di]        ; load byte from es:di

   call NEAR PTR print_hex        ; and print its hex representation

   mov ah,4eh                     ; set column for byte ASCII representation
   sub ah,cl

   push dx                        ; preserve row counter
   call NEAR PTR print_at_col     ; print byte ASCII representation
   pop dx                         ; restore row counter

   mov ax,es                      
   cmp ax,end_seg                 ; check if current segment equals end_seg
   jne print_next_byte            ; if not proceed to next byte

   cmp di,end_off                 ; check if current offset equals end_off
   je print_end                   ; if yes stop printing

print_next_byte:
   inc di                         ; increment current offset by 1
   jnz print_loop_tail

   mov ax,es                      ; adjust segment if offset overflow detected
   add ax,1000h
   mov es,ax

print_loop_tail:
   loop print_byte                ; print next byte
   jmp print_offset               ; if last byte print the current address

print_end:
   pop es                         ; restore original es segment value
   jmp reset_state                ; reset state of the program


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Write action                    ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
write_action:
   xor ch,ch                      ; clear the upper part of cx register
   mov cl,bytes_len               ; set cx to number of bytes to write

   cmp cx,0                       ; check if there are any bytes to write
   jne write_action1
   jmp reset_state                ; finish early if no bytes to write

write_action1:
   push es                        ; save original es segment value
   les di,[dword ptr start_off]   ; load start_off value into es:di 
   
   mov bx,OFFSET bytes_wr         ; set bx to bytes array offset
   xor si,si                      ; set array index to 0

write_loop:
   mov al,byte ptr [bx + si]      ; read byte from write array to al
   mov es:[di],al                 ; save at destination address
   
   inc si                         ; increment array index
   inc di                         ; increment destination offset
   jnz write_loop_tail            ; proceed to next byte if no 
                                  ; destination offset overflow

   mov ax,es                      ; adjust segment if offset overflow detected
   add ax,1000h
   mov es,ax

write_loop_tail:   
   loop write_loop
   
   pop es                         ; restore previous es segment value
   jmp reset_state

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; File write action               ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
filew_action:
   call compare_offsets           ; validate offsets
   jnc filew_bytes

   jmp error_action

filew_bytes:
   call NEAR PTR create_file
   jnz filew_error

   push es                        ; save original es segment value
   les di,[dword ptr start_off]   ; load start_off value into es:di 
   mov si,0

filew_byte:
   mov al,es:[byte ptr di]        ; load byte from es:di into file_mem_buf
   push es
   mov es,file_mem_buf
   mov es:si,al
   pop es
   
   cmp si,F_BUF_SIZE-1 
   jne filew_byte1

   push di
   call NEAR PTR write_to_file    ; write to file
   pop di
   jnz filew_error
   mov si,-1                      ; indicate that the file buffer was flushed

filew_byte1:
   mov ax,es                      
   cmp ax,end_seg                 ; check if current segment equals end_seg
   jne filew_next_byte            ; if not proceed to next byte

   cmp di,end_off                 ; check if current offset equals end_off
   jne filew_next_byte            ; if yes stop writing to file

   cmp si,-1                      ; if the buffer was already flushed we
   je filew_close                 ; may close the file

   call NEAR PTR write_to_file    ; write the remaining bytes and close the
   jnz filew_error                ; file
   jmp filew_close

filew_next_byte:
   inc si
   inc di                         ; increment current offset by 1
   jnz filew_byte

   mov ax,es                      ; adjust segment if offset overflow detected
   add ax,1000h
   mov es,ax

   jmp filew_byte

filew_close:
   call NEAR PTR close_file       ; close file after write is complete
   jnz filew_error

filew_end:
   pop es                         ; restore original es segment contents
   jmp reset_state

filew_error:
   mov bx,OFFSET file_err_string  ; print file error message
   print_string @data,bx
   jmp error_action


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; File read action                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
filer_action:
   push es                        ; save original es segment value
   call NEAR PTR open_file
   jnz filer_error

   les di,[dword ptr start_off]   ; load start_off value into es:di 

filer_bytes:
   call NEAR PTR read_from_file
   cmp al,1
   je filer_close

   cmp al,2
   je filer_error
   
   xor si,si                      ; clear the read bytes index
   mov cx,bx                      ; copy the length of bytes read
   
filer_byte:
   push es
   mov es,file_mem_buf

   mov al,es:[byte ptr si]        ; load byte from file_mem_buf
   pop es
   mov es:[byte ptr di],al        ; and save at es:di

   inc si
   inc di                         ; increment current offset by 1
   jnz filer_byte_end

   mov ax,es                      ; adjust segment if offset overflow detected
   add ax,1000h
   mov es,ax

filer_byte_end:
   loop filer_byte             
   jmp filer_bytes

filer_close:
   call NEAR PTR close_file       ; close file after write is complete
   jnz filer_error

filer_end:
   pop es                         ; restore original es segment contents
   jmp reset_state

filer_error:
   pop es
   mov bx,OFFSET file_err_string  ; print file error message
   print_string @data,bx
   jmp error_action


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Error action                    ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
error_action:
   mov ax,@data                   ; in case of premature failure restore es
   mov es,ax
   print BELL

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Reset state                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
reset_state:
   mov cx,END_OF_STATE            ; set cx to number of state variables bytes
   mov di,OFFSET input            ; set di to the offset of the 1st variable
   mov al,0                       ; set al to to clear consecutive bytes
reset_state1:
   stosb                          ; clear state variable byte
   loop reset_state1                     

   print CR
   print LF
   print LF
   jmp start4

resize_error:
   push ax                        ; preserve resize error code
   mov bx,OFFSET resize_err_string ; print memory resize error message
   print_string @data,bx

   pop ax                         ; restore and print resize error code
   print_digit al
   jmp finish


alloc_error:
   push ax                        ; preserve allocation error code
   mov bx,OFFSET f_buf_err_string ; print memory allocation error message
   print_string @data,bx

   pop ax                         ; restore and print allocation error code
   print_digit al

finish:
   exit                           ; exit to DOS


; Validates start versus end segments & offsets.
; Adjusts end segment & offsets for single byte read.
; C=1 if end segment/offset is below start segment/offset
;
; destroys ax
compare_offsets PROC
   mov ax,end_seg                 ; check if end_seg is 0, this indicates
   cmp ax,0                       ; possibility of single address read
   jne compare_seg

   mov ax,end_off                 ; check if end_off is 0, this determines
   cmp ax,0                       ; single address read
   jne compare_seg

   mov ax,start_seg               ; single address will be read, copy start
   mov end_seg,ax                 ; to end offsets and segments.
   mov ax,start_off
   mov end_off,ax

   jmp compare_success

compare_seg:
   mov ax,start_seg               ; compare start_seg to end seg
   cmp ax,end_seg
   je compare_off                 ; if equal then compare offsets
   jb compare_success             ; if lesser then start printing

   jmp compare_failure            ; if greater then try again

compare_off:
   mov ax,start_off               ; if equal then we must compare offsets
   cmp ax,end_off                 ; if start_off greater then try again
   ja compare_failure

compare_success:
   clc
   ret

compare_failure:
   stc
   ret

ENDP

END main
