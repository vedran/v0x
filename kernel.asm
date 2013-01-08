[org 0x0200]

ReadMemInit: ; es:di is the destination buffer for the 24byte entries
    xor ebx, ebx ; clear ebx
    mov edx, 0x0534D4150 ; SMAP(system address map) magic number
    mov eax, 0xE820 ; E820 is the function call for detecting upper memory
    mov ecx, 24 ; increment in 24 byte chunks
    mov [es:di + 20], dword 1 ; set last dword to 1
                              ; this is the ACPI 3.0 extended attributes bitfield
                              ; setting to 1 means this entry is not ignored
    int 0x15 ; call the interrupt
    jc ReadMemFail ; if we're getting a carry flag on the first call, we've failed

    cmp ebx, 0x0 ; if ebx is zero after the first call, then our list only has one entry, we've failed
    je ReadMemFail

    mov edx, 0x0534D4150 ; apparently some BIOSes will mangle this register
    cmp edx, eax ; eax should be set to 0x534D1450 (SMAP) on success
    jne ReadMemFail
    jmp ReadMemProcessElement

ReadMemFail:
    mov ah, 0x0E
    mov al, '?'
    int 10h

ReadMemSetup:
    mov eax, 0xe820 ; eax and ecx both are changed during the interrupt call
    mov ecx, 24 ; keep incrementing by 24 bytes
    mov [es:di + 20], dword 1 ; once again, ACPI 3.0 compatibility
    int 0x15
    jc ReadMemComplete
    mov edx, 0x0534D4150  ; this may have been mangled by the BIOS

ReadMemProcessElement:
    jcxz ReadMemSkip ; jump if CX is 0, meaning this entry has a length of 0
    cmp cl, 20 ; check if we received 24 bytes (ACPI 3.x)
    jbe ReadMemNotExtended ; normal <= 20 byte response, not ACPI 3.x

    ; last 4 bytes of 24 byte entry: ACPI 3.x extended attributes, ignore these attributes if first bit is 0
    ;               second bit says whether the entry is non-volatile (if the bit is said)
    ;               remaining ACPI bits are undefined
    test byte [es:di + 20], 1 ; look for that ignore bit
    je ReadMemSkip

ReadMemNotExtended:
    ; so if we've loaded 20 bytes (not ACPI 3.x), that's 8 + 8 + 4 bytes
    ; first 8 bytes = base memory address
    ; second 8 bytes = length of this memory region
    ; next 4 bytes = region type

    mov ecx, [es:di + 12] ; upper dword of region length
    or ecx, [es:di + 8]  ; lower dword of region length
    jz ReadMemSkip ; skip entires of with region length 0

    pushad

    mov ax, [es:di + 4] ;
    call PrintASCII16bit
    mov ax, [es:di + 2] ;
    call PrintASCII16bit
    mov ax, [es:di + 0] ;
    call PrintASCII16bit

    mov edx, ','
    call PrintChar

    mov ax, [es:di + 12] ; upper dword of region length
    call PrintASCII16bit
    mov ax, [es:di + 10] ; upper dword of region length
    call PrintASCII16bit
    mov ax, [es:di + 8]  ; lower dword of region length
    call PrintASCII16bit
    mov edx, ','
    call PrintChar

    mov eax, [es:di + 16] ; region type
    call PrintASCII16bit
    mov edx, 0x0d
    call PrintChar
    mov edx, 0x0a
    call PrintChar

    popad
    add di, 24

ReadMemSkip:
    test ebx, ebx
    jne ReadMemSetup

ReadMemComplete:
    ;call Sample_Read
    ;call PrintASCII16bit
    ; setup a new thread executing this program
    ; jmp 0x0500
    ;mov eax, 0x0500
    ;call NewThread

    cli
    hlt

%if 0

; expects thread entry point to be stored in eax
NewThread:
    ; stack base at SS:EBP
    ; current stack top at SS:ESP

    pushad
    mov ebp, esp
    call eax
    popad
    ret



Sample_Reset:
    mov ah,0x00 ; reset disk function
    mov dl,0x00 ; drive number
    int 0x13    ; BIOS interrupt
jc Sample_Reset ; try again if there was an error

Sample_Read:
    mov ax, 0x07C0
    mov es, ax
    mov bx, 0x0500  ; ES:BX = 0x07C0:0500, lets load our hello program here

    mov ah, 0x02    ; read function
    mov cl, 0x05    ; which sector to start reading
    mov al, 0x01    ; how many sectors to read
    mov ch, 0x00    ; track
    mov dh, 0x00    ; head
    mov dl, 0x00    ; drive

    int 0x13

    jc Sample_Read ; try again if there was an error
    ret

%endif

; page directory has 1024 4-byte entries
; let's store it after the (4k) stack, which is just below the kernel
; like this: [ boot loader  512b ] [ buffer 8k (kernel) ] [ stack 4k ] [ page directory 4k ]
; each table has 1024, each entry is 4bytes
; each table is 1024 * 4kb = 4096bytes
; then we have 1024 of those tables, so
;

; PrintASCII16bit Procedure
; INPUT:		AX
; CLEARS/USES : CX,DX
; OUTPUT:		Converts each digit of AX into ASCII and prints it to the screen

PrintASCII16bit:
    MOV BX,0x10
    XOR CX,CX

Continue:
    XOR DX,DX		; clear DX for further use in division
    DIV BX			; divide AX by the base (16)
                    ; the remainder of this division goes into DX
                    ; the result goes into AX
    CMP DL,0xA		; if the value is less than AH (10 in decimal) it's a number
    JL IsNumber

    SUB DL,0xA		; subtract A from the value to get the offset from 'A'
    ADD DL,0x41		; add the ASCII of A to this offset
    PUSH DX			; push the final ASCII value onto the stack
    JMP Check

IsNumber:

    ADD DL,030H		; add the ASCII of '0' to the number
    PUSH DX			; push the final ASCII value onto the stack

Check:
    INC CX
    CMP CX,4		; if there are still more numbers to output
    JL Continue		; go back to the start
    XOR CX,CX

Output:
    INC CL
    POP DX
    CALL PrintChar  ; print the digit which was converted to ASCII
    CMP CL,0x4		; run this 4 times -> once for each digit
    JL Output

    RET

; *******************************************************************


; *******************************************************************
; PrintChar Procedure
; INPUT: DL
; OUTPUT: Prints the contents of DL

PrintChar:
    MOV AL, DL
    MOV AH,0x0E ; print to screen
    INT 0x10
    RET
; *******************************************************************


