bits 16

section _TEXT class=CODE

;
; int 10h=0Eh
; args: character, page
global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    ; make a new call frame
    push bp                 ; save old call frame
    mov bp, sp              ; initialize new call frame

    ; save bx
    push bx

    ; [bp + 0] - old call frame
    ; [bp + 2] - return address (small memory model => 2 bytes)
    ; [bp + 4] - first argument (character)
    ; [bp + 6] - second argument (page)
    ; note: bytes are converted to words (you can't push a single byte on the stack)
    mov ah, 0Eh
    mov al, [bp + 4]
    mov bl, [bp + 6]

    int 10h

    ; restore bx
    pop bx

    ; restore the stack frame of the caller
    mov sp, bp
    pop bp
    ret


;
; Performs a division with 64bits dividend and 32 bits divisor
; (cannot be performed by x86 div instruction in 16 bits real mode)
; input  args: dividend (64b), divisor (32b)
; output args: offset of quotient (64b), offset of remainder (64b)
;
global _x86_div64_32
_x86_div64_32:
    push bp
    mov bp, sp

    ; save registers (ax, cx, dx are saved by the caller per _decl convention)
    push bx

    xor edx, edx ; edx = 0 (clear remainder beforehand)
    mov eax, [bp+8] ; loading the 32 upper bit of the dividend into eax
    mov ecx, [bp+12] ; loading divisor into ecx
    div ecx          ; eax = upper 32 of dividend / divisor
                     ; edx = upper 32 of dividend % divisor

    mov bx, [bp+16]  ; first ouptut arg, which is the adr of oDividend
    mov [bx+4], eax  ; upper 32b of oQuotient = upper 32 of dividend / divisor

    mov eax, [bp+4]  ; eax = lower 32b of dividend
                     ; edx = old remainder
    div ecx          ; eax = (rem of 1st div + lower 32b of dividend) / divisor
                     ; edx = (rem of 1st div + lower 32b of dividend) % divisor

    mov [bx], eax    ; upper 32b of oQuotient = (rem of 1st div + lower 32b of dividend) / divisor
    mov bx, [bp+18]  ; bx = adr of oRemainder
    mov [bx], edx

    ; restore registers
    pop bx

    mov sp, bp
    pop bp
    ret
