org 0x7C00 ;every address is offset by this address
bits 16 ;we tell asm to emit 16 bits code

%define ENDL 0x0D, 0x0A ; endline character

;
; FAT12 header
; (The bootloader is written in FAT12 FS on the floppy disk, so it needs to have the FAT12 headers at the beginning)
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes 
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 210 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sectors_count:    dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number
ebr_volume_label:           db 'BAST OS    '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

start:
    jmp main

;
; Prints a string to the screen.
; Params:
;   - ds:si points to the string
;
puts:
    ; save registers we will modify
    push si ; pushes to stack
    push ax

.loop:
    lodsb ; loads the byte at ds:si into al, then increments si
    or al, al ; sets the Zero flag if the result is zero (meaning null character).
    jz .done ; jumps to done if the zero flag is set
    
    mov ah, 0x0E ; using bios INT 10h interrupt to write a character to the screen
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    ; restoring the registers we saved at the beginning
    pop ax
    pop si
    ret

main:

    ; setting up data segments
    ; current address = segment*16 + offset (both segment and offset are 16bits values)
    mov ax, 0 ; can't write to ds/es directly
    mov ds, ax ; cs -> current data segment
    mov es, ax ; es -> current extra segment

    ; setting up the stack
    mov ss, ax ; stack segment
    mov sp, 0x7C00 ; stack pointer (beginner of the os because it grows downwards)

    ; read something from the disk
    mov dl, [ebr_drive_number]
    mov ax, 1                       ; LBA address
    mov cl, 1                       ; 1 sector to read
    mov bx, 0x7E00                  ; data should be after the boot loader
    call disk_read

    ; printing hello world
    mov si, msg_hello
    call puts

    hlt
    
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                             ; wait for key press
    jmp 0FFFFh:0                        ; jumps to beginning of BIOS, rebooting

.halt:
    cli                                 ; disable interrupts to prevent OS from escaping halt
    hlt
    
;
; Disk routines
;

;
; Convert LBA (virtual) to CHS (physical) adress on floppy disk
; Parameters:
;   - ax : LBA address
; Returns:
;   - cx [bits 0 to 5]  : sector number
;   - cx [bits 6 to 15] : cylinder
;   - dh [head]
lba_to_chs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack
    inc dx                              ; dx = ( LBA % SectorsPerTrack) + 1 = sector
    mov cx, dx                          ; cx = sector
    
    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % heads = head
    mov dh, dl                          ; result was in dl (1 byte) -> move to dh as expected
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah
    
    ; cx is special because cylinder overlaps on CH and CL upper two bits
    ; CX =       ---CH--- ---CL---
    ; cylinder : 76543210 98
    ; sector   :            543210
    
    pop ax
    mov dl, al
    pop ax
    ret
    
;
; Reads sectors from a disk
; Parameters:
;   - ax : LBA address
;   - cl : number of sectors to read (up to 128)
;   - es:bx : address in memory where to load the data
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx                             ; save cl
    call lba_to_chs
    pop ax                              ; al = number of sectors to read
    mov ah, 02h
    
    mov di, 3
    
.retry:
    pusha                               ; save all registers
    stc                                 ; set carry flag
    int 13h
    jnc .done                           ; if carry is unset, operation successful
    
    ; disk read failed
    popa
    dec di
    test di, di
    jnz .retry
    
.fail:
    ; all disk read attemps failed
    jmp floppy_error
    
.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret
    
;
; Resets disk controller
; Parameters:
;   - dl : disk number
disk_reset:
    pusha
    mov ah, 0
    int 13h
    jc floppy_error
    popa
    ret

msg_hello: db 'Hello World!', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0;emits 0x00 510 - length_of_our_current_program times
dw 0AA55h ;puts the OS signature (0xAA 0x55 16bits word)