org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A ; macro to define the endline character

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

	hlt

.halt:
	jmp .halt


msg_hello: db 'Hello, World!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
