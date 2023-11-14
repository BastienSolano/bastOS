org 0x7C00 ;every address is offset by this address
bits 16 ;we tell asm to emit 16 bits code

main:
    hlt

.halt: ;in case the program continues executing after the halt, we put it in an infinite loop to make sure it doesn't
    jmp .halt

times 510-($-$$) db 0;emits 0x00 510 - length_of_our_current_program times
dw 0AA55h ;puts the OS signature (0xAA 0x55 16bits word)