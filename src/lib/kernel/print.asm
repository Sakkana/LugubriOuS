TI_GDT          equ     0
RPL0            equ     0
SELECTOR_VIDEO  equ     (0x0003 << 3) + TI_GDT + RPL0

section .data
put_int_buffer  dq      0   ; 8 字节缓冲区

[bits 32]
section .text

; --- 实现 putstr 函数 ---
; --- 将栈中以 \0 结尾的字符串打印出来 ---
global put_str
put_str:
    ; 备份
    push ebx
    push ecx
    
    xor ecx, ecx
    mov ebx, [esp + 12]     ; 获取字符串地址，栈中结构： str, ra, ebx, ecx

    ; 循环处理
    .goon:
        mov cl, [ebx]
        cmp cl, 0       ; 字符串结尾
        jz .str_over
        
        push ecx
        call put_char
        add esp, 4      ; caller 回复现场
        
        inc ebx         ; 指向下一个字符
        jmp .goon
        
    .str_over:
        pop ecx
        pop ebx
        ret



; --- 实现 putchar 函数 ---
; --- 将栈中的一个字符打印到光标所在的位置 ---

global put_char

put_char:
    pushad  ; 备份 32 位寄存器环境

    ; gs <- 视频段选择子
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    ; --- 获取当前光标位置 ---
    ; 高 8 位
    mov dx, 0x3d4   ; 索引寄存器
    mov al, 0x0e    ; 用于提供光标坐标高 8 位
    out dx, al      ; 访问端口
    
    mov dx, 0x03d5  ; 读写数据端口 0x03d5 获取光标位置
    in  al, dx      ; 获取光标位置高 8 位

    mov ah, al

    ; 低 8 位
    mov dx, 0x3d4
    mov al, 0x0f    ; 低 8 位
    out dx, al

    mov dx, 0x03d5
    in al, dx

    ; 将光标存入 bx
    mov bx, ax
    ;mov bx, 320

    ; 获取待打印的字符
    mov ecx, [esp + 36]     ; pushad 压入 4 x 8 = 32 byte + ra = 46 byte

    ; CR = 0xd, LF = 0xa, backspace = 0x8
    cmp cl, 0xd
    jz .is_carriage_return
    cmp cl, 0xa
    jz .is_line_feed
    cmp cl, 0x8
    jz .is_backspace

    jmp .put_other


; --- 各种情况的 handler ---


.is_backspace:
    ; bx 放了当前光标的位置
    dec bx

    shl bx, 1   ; 得到光标的实际地址，因为一个字符占 2 byte，所以需要将 bx << 1
    mov byte [gs:bx], 0x20  ; 低地址

    inc bx
    mov byte [gs:bx], 0x07  ; 高地址
    
    shr bx, 1

    jmp .set_cursor


.put_other:
    shl bx, 1
    
    mov [gs:bx], cl
    
    inc bx
    mov byte [gs:bx], 0x07
    
    shr bx, 1
    inc bx

    cmp bx, 2000
    jl .set_cursor


.is_line_feed:              ; 换行符 LF \n
.is_carriage_return:        ; 回车符 CR \r
    xor dx, dx
    mov ax, bx
    mov si, 80

    div si

    sub bx, dx

.is_carriage_return_end:
    add bx, 80
    cmp bx, 2000

.is_line_feed_end:
    jl .set_cursor

.roll_screen:
    cld
    mov ecx, 960    ; 若超出屏幕，开始滚屏

    ; 将 1-24 行搬运到 0-23 行
    mov esi, 0xc00b80a0     ; 第 1 行行首
    mov edi, 0xc00b8000     ; 第 0 行行首
    rep movsd

    ; 将第 24 行填充为空白
    mov ebx, 3840   ; 最后一行的第一个字节：80 * 24 * 2 = 1920 * 2
    mov ecx, 80     ; 一行有 80 个字符，每次清空 1 个字符

.cls:
    mov word [gs:ebx], 0x0720    ; 黑底白色空白键
    add ebx, 2
    loop .cls
    mov bx, 1920    ; 当前光标位置

.set_cursor:
    ; 将光标设置为 bx 的值，putchar 之后更新 CRT 寄存器
    ; 设置高八位
    mov dx, 0x3d4
    mov al, 0x0e
    out dx, al

    mov dx, 0x3d5
    mov al, bh
    out dx, al

    ; 设置低八位
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al

    mov dx, 0x3d5
    mov al, bl
    out dx, al

    .put_char_done:
    popad
    ret

global put_int
put_int:
    pushad
    mov ebp, esp
    mov eax, [ebp + 4 * 9]  ; 8 个寄存器 + ra
    mov edx, eax            ; 整数的编码

    mov edi, 7              ; 缓冲中的初始 offset (小端编码)
    mov ecx, 8              ; 32 位整数，8 byte
    mov ebx, put_int_buffer

    ; 十六进制的方式从低位到高位逐个处理
    ; 共处理 8 个十六进制数字
    .16based_4bits:
        and edx, 0x0000000F     ; 低 4 位掩码
        cmp edx, 9
        jg .is_A2F              ; A ~ F

    add edx, '0'
    jmp .store

    .is_A2F:
        sub edx, 10
        add edx, 'A'
        jmp .store

    .store:
        ; ebx 是缓冲区的基址
        ; edi 是下标
        mov [ebx + edi], dl
        dec edi
        shr eax, 4
        mov edx, eax
        loop .16based_4bits

    .ready_to_print:
        inc edi     ; -1 + 1
    
    ; 全部都是 0
    .skip_prefix_0:
        cmp edi, 8
        je .full0

    ; 找出连续的前导 0
    .go_on_skip:
        mov cl, [put_int_buffer + edi]
        inc edi
        cmp cl, '0'
        je .skip_prefix_0
        dec edi
        jmp .put_each_num

    .full0:
        mov cl, '0'

    .put_each_num:
        push ecx
        call put_char
        add esp, 4
        inc edi
        mov cl, [put_int_buffer + edi]
        cmp edi, 8
        jl .put_each_num
        
        popad
        ret