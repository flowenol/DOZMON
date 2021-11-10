.MODEL SMALL
.DATA

INCLUDE const.inc

fcb STRUC
drive_id      DB 0
filename      DB 8 DUP(0)
extension     DB 3 DUP(0)
curr_block    DB 2 DUP(0)
record_size   DB 2 DUP(0)
file_size     DB 4 DUP(0)
date          DB 2 DUP(0)
time          DB 2 DUP(0)
reserved      DB 8 DUP(0)
curr_record   DB 0
random_record DB 4 DUP(0)
fcb ENDS

file          fcb <>
write_buf     DB 0

PUBLIC write_buf

.CODE

PUBLIC create_file
PUBLIC write_to_file
PUBLIC close_file

; Creates file. Z=0 if error.
; 
; destroys ax,dx
create_file PROC NEAR
   mov dx,OFFSET file
   mov ah,16h                     ; create file
   int 21h

   or al,al
   jnz create_file_end
   
   mov file.record_size,WR_BUF_SIZE
   pushf

   mov dx,OFFSET write_buf
   mov ah,1ah                     ; set disk transfer area address
   int 21h

   popf
create_file_end:
   retn
ENDP

; Writes byte in wr_buf to file. Z=0 if error.
;
; destroys dx, ax
write_to_file PROC NEAR
   mov dx,OFFSET file
   mov ah,15h
   int 21h

   or al,al

   retn
ENDP

; Closes file. Z=0 if error.
; 
; destroys ax,dx
close_file PROC NEAR
   mov dx,OFFSET file
   mov ah,10h
   int 21h

   or al,al
   jnz close_file_end

   pushf
   call clear_fcb
   popf
close_file_end:
   retn
ENDP

clear_fcb PROC
   push es
   push di
   push cx
   mov ax,SEG file
   mov es,ax
   mov di,OFFSET file
   mov cx,SIZE fcb

   rep stosb

   pop cx
   pop di
   pop es
   ret
ENDP

END
