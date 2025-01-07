org 0x00
bits 16

%define ENDL 0x0D, 0x0A ; macro to define the endline character


main:
   ; print hello world message
  mov si, msg_hello
  call puts


.halt:
  cli
  hlt


;
; Prints a string to the screen
; Params:
;   - ds/si points to the string
;
puts:
  ; save registers we will modify
  push si
  push ax
  push bx

.loop:
  lodsb   ; load next character from location ds/si into al register
  or al, al ; verify if next character is null (zero flag would be set then)
  jz .done

  mov ah, 0x0e
  mov bh, 0
  int 0x10

  jmp .loop

.done:
  pop bx
  pop ax
  pop si
  ret



msg_hello: db 'Hello, World from kernel!', ENDL, 0
