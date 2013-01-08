[org 0x0500]
mov al, 'h'
mov ah, 0X0E ;
int 0X10

mov al, 'i'
mov ah, 0X0E ;
int 0X10

mov al, 0x0D
mov ah, 0X0E ;
int 0X10

mov al, 0x0A
mov ah, 0X0E ;
int 0X10

NewHang:
    jmp NewHang

ret
