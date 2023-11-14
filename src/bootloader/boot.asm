org 0x7C00 ;every address is offset by this address
bits 16 ;we tell asm to emit 16 bits code

%define ENDL 0x0D, 0x0A ; endline character

;
; FAT12 header
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
ebr_volume_id:              db 12h, 34h, 56h, 78h   ;serial number
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

    ; printing hello world
    mov si, msg_hello
    call puts

    hlt

.halt: ;in case the program continues executing after the halt, we put it in an infinite loop to make sure it doesn't
    jmp .halt

msg_hello: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0;emits 0x00 510 - length_of_our_current_program times
dw 0AA55h ;puts the OS signature (0xAA 0x55 16bits word)