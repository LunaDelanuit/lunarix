org 0x7C00 ; BIOS looks for a boot sector at this address
bits 16    ; BIOS starts in 16-bit real mode

; FAT12 BIOS Parameter Block
; In reference to a standard 1.44MB Floppy Disk

jmp short start
nop

bdb_oem:                    db 'LURIX5.1'               ; 8 byte OEM Identifier. 5.1 is used for compatibility reasons.
                                                        ; LURIX can be referred to as a shorter name of Lunarix.
bdb_bytes_per_sector:       dw 512                      ; 512 bytes per sector
bdb_sectors_per_cluster:    db 1                        ; 1 sector per cluster
bdb_reserved_sectors:       dw 1                        ; 1 reserved sector
bdb_fat_count:              db 2
bdb_dir_entries:            dw 0xE0                     ; 2 directory entries
bdb_total_sectors:          dw 2880                     ; 2880 total sectors * 512 bytes per sector = 1.44MB
bdb_media_desc_type:        db 0xF0                     ; 0xF0 indicates 3.5" diskette
bdb_sectors_per_fat:        dw 9                        ; 9 sectors per fat
bdb_sectors_per_track:      dw 18                       ; 18 sectors per track
bdb_heads:                  dw 2                        ; 2 heads
bdb_hidden_sectors:         dd 0                        ; 0 hidden sectors
bdb_large_sectors:          dd 0                        ; 0 large sectors

; Extended Boot Record
ebr_drive_number:           db 0                        ; 0x00 = floppy, 0x80 = hdd
                            db 0                        ; reserved byte
ebr_signature:              db 0x29                     ; 0x29 refers to fully compliant, standard signature
ebr_volume_id:              db 0x41, 0x4E, 0x55, 0x4C   ; volume signature can have anything
ebr_volume_label:           db 'LUNARIX 0.1'            ; 11 byte string
ebr_system_id:              db 'FAT12   '               ; 8 byte string represents FAT filesystem type

start:
    ; setup data segments
    mov ax, 0
    mov dx, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00

    ; read from disk
    mov [ebr_drive_number], dl

    mov ax, 1      ; read second sector of disk
    mov cl, 1      ; read 1 sector
    mov bx, 0x7E00 ; data should be after the boot sector
    call disk_read

    ; print message
    mov si, msg
    call puts

    jmp halt

disk_err:
    mov si, msg_disk_err
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 0x16     ; BIOS wait for key strike
    jmp 0xFFFF:0 ; jump to beginning of BIOS address, should reboot

halt:
    cli
.loop:
    hlt
    jmp .loop

; Prints a null-terminated string.
; Args:
;   ds:si = points to string
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


; LBA to CHS conversion
;
; LBA = Logical Block Address
; CHS = Cylinder-Head Sector
;
; 2 constants
;   # of sectors per track/cylinder (on a single side)
;   # of heads per cylinder
;
; sector    = (LBA % sectors per track) + 1
; head      = (LBA / sectors per track) % heads
; cylinder  = (LBA / sectors per track) / heads
;
; Converts an LBA address to a CHS address
; Args:
;   ax = LBA address
; Returns:
;   cx [bits 0-5] = sector number
;   cx [bits 6-15] = cylinder
;   db = head
lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]    ; ax = LBA / sectors per track
                                        ; dx = LBA & sectors per track
    inc dx                              ; dx = (above) + 1 = sector
    mov cx, dx                          ; cx = dx

    xor dx, dx
    div word [bdb_heads]                ; ax = (LBA / sectors per track) / heads = cylinder
                                        ; dx = (LBA / sectors per track) % heads = head
    mov dh, dl                          ; dl = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; higher 2 bits of cylinder in CL

    pop ax
    mov dl, al
    pop ax
    ret

; Read sectors from disk
; Args:
;   ax    = LBA address
;   cl    = # of sectors to read
;   dl    = drive number
;   es:bx = memory addres to store data
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax

    mov ah, 0x02        ; call BIOS interrupt
    mov di, 3           ; retry 3 times

.retry:
    pusha               ; push all registers to stack
    stc                 ; set carry flag
    int 0x13            ; BIOS read sectors; is carry flag cleared?
    jnc .done           ; yes
    popa

    call disk_reset     ; no; read failed
    dec di
    test di, di         ; is di 0?
    jnz .retry          ; no; retry again

.fail: ; yes; reading sectors failed
    jmp disk_err

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Reset disk controller
; Args:
;   dl = drive number
disk_reset:
    pusha
    mov ah, 0
    stc
    int 0x13
    jc disk_err
    popa
    ret

msg:          db "Hello, world!", 0x0D, 0x0A, 0
msg_disk_err: db "Err; unable to read Floppy.", 0x0D, 0x0A, 0
msg_key_wait: db "Strike any key to reboot.", 0x0D, 0x0A, 0

times 510-($-$$) db 0 ; fill rest of boot sector with empty data
db 0x55, 0xAA ; BIOS checks for this signature to determine if the sector is bootable
