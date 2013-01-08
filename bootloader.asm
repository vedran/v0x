org 0
bits 16

jmp short start
nop

; disk description table bios parameter block

OEMLabel            db "BOOTDISC"
BytesPerSector      dw 512
SectorsPerCluster   db 1
ReservedForBoot     dw 1        ; number of sectors reserved for boot record
NumberOfFats        db 2        ; number of copies of the FAT
RootDirEntries      dw 224      ; number of entries in root dir (each one is 32 bytes)
                               ; so 224 entries * 32 bytes per entry = 7168 total bytes
                                ; each sector is 512 bytes, so 7168 / 512 = 14 sectors to read
LogicalSectors      dw 2880     ; Number of logical sectors
MediaByte           db 0x0F0    ; media descriptor byte
SectorsPerFat       dw 9        ; Sectors per FAT
SectorsPerTrack     dw 18       ; 36 sectors /cylinder
Sides               dw 2        ; double sided disk
HiddenSectors       dd 0        ; 0 hidden sectors
LargeSectors        dd 0        ; 0 large sectors
DriveNo             dw 0
Signature           db 41       ; floppy has a sig of 41
VolumeID            dd 0x00000000; any number
VolumeLabel         db "VBOS     "
FileSystem          db "FAT12   "

start:
    mov ax, 0x07C0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    cli
    add ax, 544 ; 544 = 512 paragraphs + 32 paragraphs
                ; one paragraph = 16 bytes
                ; so 544 paragraphs = 512 bytes+ 8192 bytes
                ; now we've setup our 8k buffer for reading
                ; which lives after the 512 bytes of bootloader code

    mov ss, ax  ; start the stack after the buffer
    mov sp, 0x1000
    sti

floppy_reset:
    mov ah,0x00 ; reset disk function
    mov dl,0x00 ; drive number
    int 0x13    ; BIOS interrupt

    jc floppy_reset ; try again if there was an error

floppy_read:
    mov ax, 0x07C0
    mov es, ax
    xor cx, cx
    mov bx, [buffer_start]; ES:BX = 0x07C0:0200, the start of the reading buffer
    mov cl, 2       ; which sector to start reading, which is 19
                    ; because the first 18 sectors are FATs
                    ; so sector 19 is the start of the root directory region
    mov al, 14      ; how many sectors to read, 14 is the max number of root sectors
    mov ah, 0x02    ; read function
    mov ch, 0x00    ; track
    mov dh, 0x01    ; head
    mov dl, 0x00    ; drive

    int 0x13

    jc floppy_read ; try again if there was an error

; if we managed to read the floppy
; then let's look for kernel.bin
floppy_read_success:
    ; root directory is 32 bytes
    ; first 11 bytes are the file name + extension

    ; loop through all possible root directory entries
    mov cx, 16; word [RootDirEntries]
    mov di, [buffer_start]
    ; search for 'kernel.bin' in root directory
.loop:
    push cx
    mov cx, 11 ; 11 character filename + extension
    mov si, kernel_image_name
    push di
rep cmpsb
    pop di
    je load_kernel_fat
    pop cx
    add di, 32 ;
    loop .loop

    mov al, 'n'
    mov ah, 0X0E ;
    int 0X10
    cli
    hlt
    jmp kernel_not_found

load_kernel_fat:
    mov si, kernel_loading_success
    call print_string
    cli
    hlt

    ; we've loaded the root directory + files entry for kernel
    ; now it's time to load the FAT for kernel.bin
    ; bytes 26-27 represent the first cluster
    ; and bytes 28-32 are for the file size
    mov dx, [di + 26] ; store the starting cluster number of the file

    ; to load the FATs we need to get the size of the two FATs
    xor eax, eax
    mov al, [NumberOfFats] ; number of FATs * size of one FAT
    mul word [SectorsPerFat]
    mov cx, ax

    ; start reading right after the reserved boot sector
    ; this is also the start of the FATs
    mov ax, word [ReservedForBoot]
    mov bx, 0x0200 ; copy FAT over root directory

    call read_fat_sectors

read_fat_sectors:

; convert Logical Block Addressing to Cluster Head Sector
; absolute sector = (logical sector / sectors per track) + 1
; absolute head = (logical sector / sectors per track) % number of heads
; absolute track = logical sector / ( sectors per track * number of heads)

kernel_not_found:
    mov si, kernel_loading_failed
    call print_string
    cli
    hlt

print_string:
    pushad
    .loop:
        lodsb                ; load byte from SI register
        or al, al            ; check if 0 byte
        jz short .done  ; if so - stop
        mov ah, 0x0E          ; function - print text tty

        int 0x10             ; BIOS interrupt

        jmp .loop       ; continue with next char
    .done:
        popad
        ret


;;;;;;;;;;;;;;;;;;;;; globals ;;;;;;;;;;;;;;;;;;;;;;;;;;;

buffer_start dw 0x0200
kernel_loading_failed db "kernel.bin not found!",0
kernel_loading_success db "v0x kernel (kernel.bin) successfully loaded!",0
kernel_image_name db "KERNEL  BIN" ; load kernel from here

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fill the rest of the boot sector
times ($$-$+0x01FE) int3
dw 0xAA55
