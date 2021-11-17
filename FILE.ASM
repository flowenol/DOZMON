.MODEL SMALL
.DATA

INCLUDE const.inc

fcb STRUC
drive_id      DB 00h              ; default drive
filename      DB 8 DUP(0)
extension     DB 3 DUP(0)
curr_block    DW 00h
record_size   DW 00h
file_size     DW 2 DUP(0)
date          DB 2 DUP(0)
time          DB 2 DUP(0)
reserved      DB 8 DUP(0)
curr_record   DB 00h
random_record DW 2 DUP(0)
fcb ENDS

file          fcb <>
write_buf     DB WR_BUF_SIZE DUP(0)

f_name        DB 'test    '
f_ext         DB 'bin'

PUBLIC write_buf

.CODE

PUBLIC create_file
PUBLIC write_to_file
PUBLIC close_file

; Creates file. Z=0 if error.
; 
; destroys ax,dx,cx,si,di
create_file PROC NEAR
   mov ax,SEG f_name
   mov es,ax

   mov cx,8
   mov si,OFFSET f_name
   mov di,OFFSET file.filename
   rep movsb

   mov cx,3
   mov si,OFFSET f_ext
   mov di,OFFSET file.extension
   rep movsb

   mov dx,OFFSET file
   mov ah,16h                     ; create file
   int 21h

   or al,al

   retn
ENDP

; Writes si bytes in write_buf to file. Z=0 if error.
;
; destroys dx, ax, bx, cx, si
write_to_file PROC NEAR
   mov dx,OFFSET write_buf
   mov ah,1ah                     ; set disk transfer area address
   int 21h
   
   cmp si,WR_BUF_SIZE-1
   je write_to_file2

   mov ax,word ptr file.file_size   
   mov word ptr file.random_record,ax
   mov ax,word ptr file.file_size+2
   mov word ptr file.random_record+2,ax

   mov file.record_size,1

   mov cx,si
   inc cx
   mov bx,OFFSET write_buf   
   xor si,si

write_to_file1:
   mov dx,OFFSET file   
   mov ah,22h
   int 21h
   
   or al,al
   pushf

   add file.random_record,1
   adc file.random_record+1,0
   adc file.random_record+2,0
   adc file.random_record+3,0

   inc si
   mov al,[bx + si]
   mov write_buf,al
   
   popf

   loope write_to_file1

   jmp write_to_file_end

write_to_file2:
   mov file.record_size,si
   inc file.record_size

   mov dx,OFFSET file
   mov ah,15h
   int 21h

write_to_file_end:
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
   mov al,0
   rep stosb

   pop cx
   pop di
   pop es
   ret
ENDP

END
