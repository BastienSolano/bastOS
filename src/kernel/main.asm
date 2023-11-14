org 0x7C00 ;every address is offset by this address
bits 16 ;we tell asm to emit 16 bits code

%define ENDL 0x0D, 0x0A ; endline character

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