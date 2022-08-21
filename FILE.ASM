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

file_mem_buf  DW 00h             ; file buffer segment address

fname_buf     DB 12 DUP(0)       ; file name buffer

file_str      DB CR,LF,"enter file name: ",'$'
file_size_str DB CR,LF,"file size: ",'$'

PUBLIC file_mem_buf

.CODE

INCLUDE macros.inc

PUBLIC open_file
PUBLIC create_file
PUBLIC read_from_file
PUBLIC write_to_file
PUBLIC close_file

EXTRN read_str:NEAR
EXTRN print_number:NEAR

; Opens file. Z=0 if error.
; 
; destroys ax,dx,cx,si,di
open_file PROC NEAR
   mov bx,OFFSET file_str
   print_string @data,bx

   mov ax,SEG fname_buf
   mov es,ax
   mov di,OFFSET fname_buf
   mov si,12
   call NEAR PTR read_str

   mov si,OFFSET fname_buf
   mov ax,SEG file
   mov es,ax
   mov di,OFFSET file
   mov al,1                       ; scan off leading file name separators

   mov ah,29h                     ; parse filename into file
   int 21h 

   or al,al                       ; and check status
   jnz open_file_end              ; terminate prematurely on error

   mov dx,OFFSET file             ; open file
   mov ah,0fh                     
   int 21h

   or al,al                       ; and check status
   jnz open_file_end              ; terminate prematurely on error
   pushf                          ; preserve status

   mov bx,OFFSET file_size_str    ; print file size
   print_string @data,bx

   sub sp,4                       
   mov bx,sp

   mov ax,file.file_size          ; copy file size to stack parameter for
   mov word ptr ss:[bx],ax        ; print number
   mov ax,file.file_size + 2
   mov word ptr ss:[bx + 2],ax

   call NEAR PTR print_number
   add sp,4                       ; restore stack

   popf                           ; restore status
open_file_end:
   retn
ENDP


; Creates file. Z=0 if error.
; 
; destroys ax,dx,cx,si,di
create_file PROC NEAR
   mov bx,OFFSET file_str
   print_string @data,bx

   mov ax,SEG fname_buf
   mov es,ax
   mov di,OFFSET fname_buf
   mov si,12
   call NEAR PTR read_str

   mov si,OFFSET fname_buf
   mov ax,SEG file
   mov es,ax
   mov di,OFFSET file
   mov al,1                       ; scan off leading file name separators

   mov ah,29h                     ; parse filename into file
   int 21h 

   or al,al                       ; and check status
   jnz create_file_end            ; terminate prematurely on error

   mov dx,OFFSET file             ; create file
   mov ah,16h                     
   int 21h

   or al,al                       ; and check status

create_file_end:
   retn
ENDP

; Reads single byte from file to file_mem_buf. Z=0 if error. 
; al=01 or al=03 if EOF. Returns number of read_bytes in bx.
;
; destroys ax,dx,bx
read_from_file PROC NEAR
   push ds

   mov ds,file_mem_buf            ; set disk transfer area to file_mem_buf
   mov dx,0
   mov ah,1ah
   int 21h

   pop ds

   mov file.rec_size,F_BUF_SIZE   ; and set the record size to F_BUF_SIZE bytes

   mov dx,OFFSET file             ; read from file
   mov ah,14h
   int 21h

   mov bx,F_BUF_SIZE              ; set the default length of bytes read
   or al,al                       ; check status
   pushf
   jz read_from_file_end

   cmp al,1                       ; if EOF then do nothing more
   jz read_from_file_end
   
   cmp al,3                       ; if partial record read at EOF then calculate
   jnz read_from_file_end         ; read length

   push ax                        ; save al
   mov dx,file.file_size+2        ; divide file.file_size by F_BUF_SIZE 
   mov ax,file.file_size

   mov bx,F_BUF_SIZE

   div bx

   mov bx,dx                      ; copy tail number of bytes to bx
   pop ax                         ; restore al
read_from_file_end:
   popf
   retn
ENDP


; Writes si bytes in file_mem_buf to file. Z=0 if error.
;
; destroys dx,ax,bx,cx,si,di
write_to_file PROC NEAR
   push ds

   mov ds,file_mem_buf            ; set disk transfer area to file_mem_buf
   mov dx,0
   mov ah,1ah
   int 21h

   pop ds
   
   cmp si,F_BUF_SIZE-1            ; if si is equal to buffer size
   je write_to_file2              ; then proceed with sequential write

   mov ax,file.file_size          ; else set random_record to file size
   mov file.random_rec,ax
   mov ax,file.file_size+2
   mov file.random_rec+2,ax

   mov file.rec_size,1            ; and set the record size to 1 byte

   mov cx,si                      ; set cx to the number of bytes in buffer
   inc cx
   
   push es                        ; set es segmen register to file_mem_buf
   mov es,file_mem_buf
   xor si,si
   xor di,di

write_to_file1:
   mov dx,OFFSET file             ; write single byte from file_mem_buf
   mov ah,22h
   int 21h
   
   or al,al                       ; check and preserve status
   pushf

   add file.random_rec,1          ; increment random_record
   adc file.random_rec+1,0
   adc file.random_rec+2,0
   adc file.random_rec+3,0

   inc si                         ; write next byte in file_mem_buf to 1st
   mov al,es:si                   ; position
   mov es:di,al
   
   popf                           ; restore check status

   loope write_to_file1           ; loop while cx !=0 and Z=1

   pop es

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
