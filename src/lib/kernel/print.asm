TI_GDT          equ     0
RPL0            equ     0
SELECTOR_VIDEO  equ     (0x0003 << 3) + TI_GDT + RPL0

[bits 32]
section .text

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

