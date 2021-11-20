.MODEL SMALL
.DATA

INCLUDE const.inc

fcb STRUC
drive_id      DB 00h              ; default drive
filename      DB 8 DUP(0)
extension     DB 3 DUP(0)
curr_block    DW 00h
rec_size      DW 00h
file_size     DW 2 DUP(0)
date          DB 2 DUP(0)
time          DB 2 DUP(0)
reserved      DB 8 DUP(0)
curr_rec      DB 00h
random_rec    DW 2 DUP(0)
fcb ENDS

file          fcb <>             ; file structure
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

   mov dx,OFFSET file             ; create file
   mov ah,16h                     
   int 21h

   or al,al                       ; and check status

   retn
ENDP

; Writes si bytes in write_buf to file. Z=0 if error.
;
; destroys dx,ax,bx,cx,si
write_to_file PROC NEAR
   mov dx,OFFSET write_buf
   mov ah,1ah                     ; set disk transfer area address to write_buf
   int 21h
   
   cmp si,WR_BUF_SIZE-1           ; if si is equal to buffer size
   je write_to_file2              ; then proceed with sequential write

   mov ax,file.file_size          ; else set random_record to file size
   mov file.random_rec,ax
   mov ax,file.file_size+2
   mov file.random_rec+2,ax

   mov file.rec_size,1            ; and set the record size to 1 byte

   mov cx,si                      ; set cx to the number of bytes in buffer
   inc cx
   mov bx,OFFSET write_buf        ; set bx to buffer offset
   xor si,si

write_to_file1:
   mov dx,OFFSET file             ; write single byte from write_nuf
   mov ah,22h
   int 21h
   
   or al,al                       ; check and preserve status
   pushf

   add file.random_rec,1          ; increment random_record
   adc file.random_rec+1,0
   adc file.random_rec+2,0
   adc file.random_rec+3,0

   inc si                         ; write next byte in write_buf to 1st
   mov al,[bx + si]               ; position
   mov write_buf,al
   
   popf                           ; restore check status

   loope write_to_file1           ; loop while cx !=0 and Z=1

   retn                           ; end writing to file

write_to_file2:
   mov file.rec_size,si           ; set file rec_size to the size of whole
   inc file.rec_size              ; buffer

   mov dx,OFFSET file             ; write contents in buffer sequentially
   mov ah,15h
   int 21h

   or al,al

   retn
ENDP

; Closes file. Z=0 if error.
; 
; destroys ax,dx
close_file PROC NEAR
   mov dx,OFFSET file             ; close file with designated fcb
   mov ah,10h
   int 21h
   or al,al                       ; check status

   pushf                          ; preserve status
   call clear_fcb                 ; and clear the file fcb
   popf                           ; restore status

   retn
ENDP

; Clears FCB.
;
; destroys ax
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
