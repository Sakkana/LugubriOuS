section .data
str_c_lib: db "c library says: hello world!", 0xa
str_c_lib_len equ $ - str_c_lib

str_syscall: db "syscall says: hello world!", 0xa
str_syscall_len equ $ - str_syscall

section .text
global _start

_start:
    ; --- 模拟 C 语言中的系统掉调用 write ---
    ; write(stdout, "string", len("string"))
    push str_c_lib_len
    push str_c_lib
    push 1

    call simu_write
    add esp, 12         ; caller restore stack

    ; --- 跨过 libc 库函数，直接使用系统调用 ---
    mov eax, 4      ; 4 -> write
    mov ebx, 1
    mov ecx, str_syscall
    mov edx, str_syscall_len
    int 0x80

    mov eax, 1      ; 1 -> exit
    int 0x80


simu_write:
    push ebp
    mov ebp, esp
    mov eax, 4      ; write 系统调用号

    ; ebp + 4 是返回地址
    ; ebp + 0 是备份的原先 ebp
    mov ebx, [ebp + 8]
    mov ecx, [ebp + 12]
    mov edx, [ebp + 16]
    int 0x80
    pop ebp
    ret