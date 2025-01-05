org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A ; macro to define the endline character

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
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number
ebr_volume_label:           db 'BAST OS    '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

;
; Code starts here
;

start:
  jmp main

;
; Prints a string to the screen
; Params:
;   - ds/si points to the string
;
puts:
  ; save registers we will modify
  push si
  push ax

.loop:
  lodsb   ; load next character from location ds/si into al register
  or al, al ; verify if next character is null (zero flag would be set then)
  jz .done

  mov ah, 0x0e
  mov bh, 0
  int 0x10

  jmp .loop

.done:
  pop ax
  pop si
  ret



main:
  ; setup data segments
  mov ax, 0    ; can't write to ds/es directly
  mov ds, ax
  mov es, ax

  ; setup stack
  mov ss, ax
  mov sp, 0x7C00   ; stack grows downwards from where we are located in memory

  ; print hello world message
  mov si, msg_hello
  call puts

  ; reading something from floppy disk
  ; BIOS should set DL to drive number, so we take this value and put it at address ebr_drive_number
  mov [ebr_drive_number], dl
  mov ax, 1      ; lba = 1, second sector from disk
  mov cl, 1      ; cl = 1; 1 sector to read
  mov bx, 0x7E00 ; data should be written after the bootloader, not to erase the program
  call disk_read

	cli
  hlt

;
; Error handlers
;

floppy_error:
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

wait_key_and_reboot:
  mov si, msg_key_reboot
  call puts
  mov ah, 0
  int 16h      ; wait for a keypress
  jmp 0FFFFh:0 ; jump to beginning of BIOS, should reboot

.halt:
  cli          ; disable interrupts, so the user cannot escape the halt state
  hlt

;
; Disk routines
;

;
; Converts an LBA address to a CHS (physical) one
; Parameters:
;  - ax: LBA address
; Returns:
;  - cx [bits 0-5]: sector number
;  - cx [bits 6-15]: cylinder
;  - dh: head
lba_to_chs:
  push ax
  push dx


  xor dx, dx ; sets dx to zero
  div word [bdb_sectors_per_track] ; ax = LBA / sectors_per_track
                                   ; dx = LBA % sectors_per_track
  inc dx                           ; dx = (LBA % sectors_per_track) + 1 = sector
  mov cx, dx                       ; cx = sector

  xor dx, dx                       ; dx = 0
  div word [bdb_heads]             ; ax = (LBA / sectors_per_track) / heads
                                   ; dx = (LBA / sectors_per_track) % heads
  mov dh, dl                       ; dh = head
  mov ch, al                       ; ch = cylinder (lower 8 bits)
  shl ah, 6
  or cl, ah                        ; put upper 2 bits of cylinder in cl


  pop ax
  mov dl, al
  pop ax
  ret

;
; Reads sectors from a disk
; Parameters:
;  - ax: LBA address
;  - cl: number of sectors to read (up to 128)
;  - dl: drive number
;  - es:bx: memory address where to store read data
disk_read:
  push ax
  push bx
  push cx
  push dx
  push di

  push cx                         ; temporarily save cl (number of sectors to read)
  call lba_to_chs
  pop ax                          ; al = number of sectors to read
  mov ah, 02h                     ; ah needs to be 02h for this interrupt

  mov di, 3                       ; num of retries

.retry:
  pusha                           ; save all registers, we don't know which one the BIOS modifies
  stc                            ; set carry flag, some BIOSes don't set it
  int 13h                         ; carry flag is set = memory read was successful
  jnc .done

  ; if the read failed
  popa
  call disk_reset

  dec di
  test di, di
  jnz .retry

.fail:
  ; all attempts to read memory failed
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
; Parameters
;   - dl: drive number
disk_reset:
  pusha
  mov ah, 0
  stc
  int 13h           ; int 0x13 with ah=0 resets controller
  jc floppy_error
  popa
  ret

msg_hello: db 'Hello, World!', ENDL, 0
msg_read_failed: db 'Could not read from disk', ENDL, 0
msg_key_reboot: db 'Press any key to reboot', ENDL, 0

times 510-($-$$) db 0


dw 0AA55h
