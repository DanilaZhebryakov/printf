
section .text

; flushes output buffer to stdout
; destroys: rdx
global out_buff_flush_
out_buff_flush_:
        push rdi
        push rsi
        push rcx

        mov rax, 0x01 ;write
        mov rdi, 1    ;stdout
        mov rsi, output_buff
        mov rdx, qword[output_buff_fill]
        syscall
        mov qword[output_buff_fill], 0
        pop rcx
        pop rsi
        pop rdi
    ret

;single char at al -> stdout
; Destroys: rax
global putchar_
putchar_:
    push rdx
    
    mov rdx, qword[output_buff_fill]
    add qword[output_buff_fill], 1
    mov byte[output_buff + rdx], al

    cmp al, 10 ; end of line
    je .putc_flush
    cmp rdx, output_buff_size - 1
    jnb .putc_flush
        
    pop rdx
    ret
    .putc_flush:
    call out_buff_flush_
    pop rdx
    ret

; string at si -> stdout
; expects ax = 0
; destroys: al
global puts_
puts_:
    puts_loop:
        call putchar_
        puts:
        lodsb
        test al, al
    jnz puts_loop
    ret

; hex at rax -> stdout
; destroys: rcx, rdx
puthex_:
    mov rdx, rax
    mov rcx, 16

    .loop:
        rol rdx, 4
        mov rax, rdx
        and rax, 0x0F
        mov al, byte [rdi+rax]
        call putchar_
    loop .loop
    ret

putbin_:
    mov rbx, rax
    mov rcx, 64

    .loop:
        rol rbx, 1
        mov rax, rbx
        and rax, 1
        add rax, '0'
        call putchar_
    loop .loop
    ret



; dec at rax -> stdout
; Destroys: rax, rcx, rdx, rsi, rdi
putdec_:
    cmp rax, 0
    jns .positive
    mov rdx, rax
    mov rax, '-'
    call putchar_
    mov rax, rdx
    neg rax    
    .positive:
    mov rcx, 10
    mov rsi, 1000000000 ;max 10 count
    .loop:
        xor rdx, rdx
        div rsi
        add rax, '0'
        call putchar_
        mov rdi, rdx
        xor rdx, rdx
        mov rax, rsi
        mov rsi, 10
        div rsi
        mov rsi, rax
        mov rax, rdi
    loop .loop
    ret

global printf_
; Entry: format string at rdi, all other on stack (first on top)
; Return: none
; Destroys: rax, rcx, rdx, rsi, rdi
printf_:
    mov rsi, rdi
    push rbp
    mov rbp, rsp
    xor rax, rax
    push rbx
    lea rbx, [rbp + 16] ; skip oldbp and ret addr
    jmp printf_format_loop_beg
    printf_format_loop:
        cmp al, '%'
        jnz fmt_dir
        xor rax, rax
        lodsb
        mov rdi, rax
        and al, 0x0F ; compress things
        
        cmp al, 'h' - 'a' + 1 ;al begins at 'a'-1 jtable begins at 'c'
        ja fmt_rdi
        mov rdx, qword [jtable + rax*8 - (('c'-'a'+1)*8)]
        jmp rdx

        fmt_rdi:
            mov rax, rdi
        jmp fmt_dir
        fmt_chr:
            cmp rdi, 's'
            je fmt_str
            mov al, byte [rbx]
            add rbx, 8
        fmt_dir:
            call putchar_
            jmp printf_format_loop_beg
        fmt_dec:
            mov rax, qword [rbx]
            add rbx, 8
            push rsi
            call putdec_
            pop rsi
            jmp printf_format_loop_beg
        fmt_hex:
            test rdi, 20h
                jnz .hex_low
                mov rdi, Hextable
                jmp .hex_set_end
                .hex_low:
                mov rdi, hextable
                .hex_set_end:
            mov rax, qword [rbx]
            add rbx, 8
            call puthex_
            jmp printf_format_loop_beg
        fmt_bin:
            mov rax, qword [rbx]
            sub rbx, 8
            call putbin_
            jmp printf_format_loop_beg
        fmt_str:
            push rsi
            mov rsi, qword [rbx]
            add rbx, 8
            call puts_
            pop rsi
        printf_format_loop_beg:
        lodsb
        test rax, rax
    jnz printf_format_loop
    pop rbx
    pop rbp
    ret

; system-v calling convention adapter for printf_
extern printf
global printf_c
printf_c:
    pop qword[printf_ret_save]
    mov [printf_rdi_save], rdi
    push r9
    push r8
    push rcx
    push rdx
    push rsi
    call printf_

    xor rax, rax
    pop rsi
    pop rdx
    pop rcx
    pop r8
    pop r9
    mov rdi, [printf_rdi_save]
    call printf
    jmp qword[printf_ret_save]

section .rodata
    Hextable db '0122346789ABCDEF'
    hextable db '0122346789abcdef'
    jtable   dq fmt_chr, fmt_dec, fmt_rdi, fmt_rdi, fmt_rdi, fmt_hex

section .data
    output_buff_size equ 128
    printf_rdi_save dq 0
    printf_ret_save dq 0
    output_buff_fill dq 0
section .bss
    output_buff db 128 dup(?)