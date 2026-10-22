org 0x7C00 ; BIOS looks for a boot sector at this address
bits 16    ; BIOS starts in 16-bit real mode

_start:
    ; setup data segments
    mov ax, 0
    mov dx, ax
    mov es, ax

    mov ss, ax
    mov sp, 0x7C00

    ; print message
    mov si, msg
    call puts

    cli
.loop:
    hlt
    jmp .loop

; Prints a null-terminated string.
; ds:si points to string
puts:
    push si
    push ax

.loop:
    lodsb
    or al, al ; verify if next character is null
    jz .done

    mov ah, 0x0e ; call bios interrupt
    mov bh, 0    ; set page number to 0
    int 0x10     ; BIOS print to VGA

    jmp .loop

.done:
    pop ax
    pop si
    ret

msg: db 'Hello, world!', 0x0D, 0x0A, 0

times 510-($-$$) db 0 ; fill rest of boot sector with empty data
dw 0AA55h ; BIOS checks for this signature to determine of the sector is bootable
