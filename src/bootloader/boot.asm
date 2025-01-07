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
  ; setup data segments
  mov ax, 0    ; can't write to ds/es directly
  mov ds, ax
  mov es, ax

  ; setup stack
  mov ss, ax
  mov sp, 0x7C00   ; stack grows downwards from where we are located in memory

  ; some BIOSes start us a 7C00:0000 instead of 0000:7C00
  ; make sure we start at the expected location
  push es
  push word .after
  retf

.after:
  ; BIOS should set dl register to drive number
  mov [ebr_drive_number], dl

  ; print loading message
  mov si, msg_loading
  call puts

  ; read drive parameters (sectors count and head count)
  ; instead of relying on data from formatted disk
  push es
  mov ah, 08h
  int 13h
  jc floppy_error
  pop es

  and cl, 0x3F  ; remove top 2 bits
  xor ch, ch
  mov [bdb_sectors_per_track], cx ; sector count

  inc dh
  mov [bdb_heads], dh             ; head count


  ; compute root directory LBA = reserved + fats * sectors_per_fat
  mov ax, [bdb_sectors_per_fat] ; compte LBA of root directory = reserved + fat_count * sectors_per_fat
  mov bl, [bdb_fat_count]
  xor bh, bh
  mul bx                        ; dx:ax = (fat_count * sectors_per_fat)
  add ax, [bdb_reserved_sectors] ; ax = reserved + fat_count * sectors_per_fat
  push ax

  ; compute size of root directory in sectors = (32 * number_of_entries) / bytes_per_sector
  mov ax, [bdb_dir_entries_count]
  shl ax, 5                        ; ax *= 32
  xor dx, dx
  div word [bdb_bytes_per_sector]

  test dx, dx                      ; if dx != 0, add 1
  jz .root_after_dir
  inc ax                           ; division remainder != 0, add 1
                                   ; this means that the last sector is only partially filled
.root_after_dir:
  ; read root directory
  mov cl, al                       ; cl = num of sectors to read = size of root directory
  pop ax                           ; ax = LBA of root directory
  mov dl, [ebr_drive_number]       ; dl = drive number (saved earlier)
  mov bx, buffer                   ; es:bx = buffer to write data to
  call disk_read


  ; Search for kernel.bin in the filesystem
  xor bx, bx                       ; bx = current directory index
  mov di, buffer                   ; di = LBA of current directory

.search_kernel:
  mov si, file_kernel_bin
  mov cx, 11                       ; compare up to 11 characters
  push di
  repe cmpsb                       ; repeats cmpsb cx=11 times or until the compared bytes are not equal
                                   ; cmpsb stands for "compare bytes" compares a byte in ds:si and es:di and then inc both si and di
  pop di
  je .found_kernel

  add di, 32                       ; moving to the next directory (32 bytes after)
  inc bx
  cmp bx, [bdb_dir_entries_count]  ; if current_index == bdb_dir_entries_count (we searched all entries already)
  jl .search_kernel
  jmp kernel_not_found_error

.found_kernel:
  ; di should point to the entry of kernel.bin
  mov ax, [di + 26]                ; first logical cluster low field
  mov [kernel_cluster], ax

  ; load FAT from disk into memory
  mov ax, [bdb_reserved_sectors]
  mov bx, buffer
  mov cl, [bdb_sectors_per_fat]
  mov dl, [ebr_drive_number]
  call disk_read

  ; read kernel and process FAT chain
  mov bx, KERNEL_LOAD_SEGMENT
  mov es, bx
  mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
  ; read next cluster
  mov ax, [kernel_cluster]
  add ax, 31                      ; (hardcoded :( ) first cluster = (kernel_cluster - 2) * sectors_per_cluster + start_cluster
                                  ; start sector = reserved + fats + root directory size = 1+18+134 = 33

  mov cl, 1                       ; We read only one sector because bdb_sectors_per_cluster = 1 here
  mov dl, [ebr_drive_number]
  call disk_read

  add bx, [bdb_bytes_per_sector]

  ; compute location of next cluster
  mov ax, [kernel_cluster]
  mov cx, 3
  mul cx
  mov cx, 2
  div cx                          ; ax = index of entry in FAT, dx = cluster mod 2

  mov si, buffer
  add si, ax
  mov ax, [ds:si]                 ; read entry from FAT at index ax

  or dx, dx
  jz .even

.odd:
  shr ax, 4
  jmp .next_cluster_after

.even:
  and ax, 0x0FFF

.next_cluster_after:
  cmp ax, 0x0FF8                 ; end of chain
  jae .read_finish

  mov [kernel_cluster], ax
  jmp .load_kernel_loop

.read_finish:
   ; jump to our kernel
   mov dl, [ebr_drive_number]   ; boot device number in dl, like we recevied from BIOS

   mov ax, KERNEL_LOAD_SEGMENT
   mov ds, ax
   mov es, ax

   jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

   jmp wait_key_and_reboot     ; should never happen


	cli
  hlt

;
; Error handlers
;

floppy_error:
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

kernel_not_found_error:
  mov si, msg_kernel_not_found
  call puts
  jmp wait_key_and_reboot

wait_key_and_reboot:
  mov ah, 0
  int 16h      ; wait for a keypress
  jmp 0FFFFh:0 ; jump to beginning of BIOS, should reboot

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

msg_loading: db 'Loading...', ENDL, 0
msg_read_failed: db 'Disk read fail', ENDL, 0
msg_kernel_not_found: db 'Kernel not found', ENDL, 0
file_kernel_bin: db 'KERNEL  BIN'  ; no need to null-terminate because it's always 11 characters long
kernel_cluster: dw 0

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET  equ 0

times 510-($-$$) db 0
dw 0AA55h

buffer:
