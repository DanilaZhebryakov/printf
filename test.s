extern printf_

section .text
global _start
    _start:
    push rbp
    mov rbp, rsp

    mov rdi, test_str

    push '*'
    push 0xBAAD
    push -54874
    push test_str

    call printf_

    mov rsp, rbp
    pop rbp
    mov rax, 0x3C ;exit
    mov rdi, 0 ;(0)
    syscall
section .data 
    test_str db "abcd %s %d %h %cEFG %%", 10, 0