%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR       ; loader 在实模式下的栈基址，向下生长

jmp loader_start

; --- 构建 gdt 及其内部描述符 ---
; ---------- 数据定义 ----------

; 第 0 段不用
GDT_BASE:           dd 0x0000_0000   ; 双字, 4 bytes， 低 16 位
                    dd 0x0000_0000   ;                 高 16 位

; 第 1 段：代码段
CODE_DESC:          dd 0x0000_FFFF
                    dd DESC_CODE_HIGH4

; 第二段：数据段，栈段
DATA_STACK_DESC:    dd 0x0000_FFFF
                    dd DESC_DATA_HIGH4

; 第三段：显存段
VIDEO_DESC:         dd 0x8000_0007          ;limit=(0xbffff-0xb8000)/4k=0x7fff/4k=0x7fff/0xfff=0x7
                    dd DESC_VIDEO_HIGH4


GDT_SIZE equ $ - GDT_BASE   ; gdt 所占的内存大小
GDT_LIMIT equ GDT_SIZE - 1  ; gdt 的段界限

; times 是伪指令
times 60 dq 0               ; 预留 60 个描述符的空位，dq 是 define-quad-word，定义 4 word = 8 byte

; 内存容量
; 这里的地址是 0xb00
; 前面定义了 4 个段，预留了 60 个段
; (4 + 60) x 8 byte = 512 byte
; 0x900 + 0x200 = 0xb00
total_memory dd 0

; gdt 指针，前 2 byte 是 gdt 界限，后 4 byte 是 gdt 起始地址
; | gdt 内存起始地址 | gdt 界限 |
gdt_ptr     dw  GDT_LIMIT
            dd  GDT_BASE
; loadermsg   db  '2 load loader succeed!'

; 对齐：4 + 2 + 4 + 2 + 244 = 256
ards_buf times 244 db 0     ; 缓冲区
ards_nr dw 0                ; count ards 数量

; 定义对应的三个选择子
SELECTOR_CODE   equ (0x0001<<3) + TI_GDT + RPL0
SELECTOR_DATA   equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO  equ (0x0003<<3) + TI_GDT + RPL0


loader_start:
; ---
; loader 起始地址
; ---

    ; --- 打印字符串 ---
    ; mov sp, LOADER_BASE_ADDR
    ; mov bp, loadermsg           ; es:bp 字符串地址 ah 功能号 bh 页码 bl 属性 cx 字符串长度 
    ; mov cx, 22                  ; 字符串长度，int 10 的参数
    ; mov ax, 0x1301               ; ah = 13 al = 0x1
    ; mov bx, 0x00af               ; 页号 0，蓝底粉红字 1f
    ; mov dx, 0x0100               ; dh = 0x18 == 24 最后一行 0 列开始
    ; int 0x10

    ; 获取内存容量
    mov sp, LOADER_BASE_ADDR
    xor ebx, ebx                ; ebx 清零
    mov ax, 0
    mov es, ax                  ; @es: 构成 [es:di] 指向缓冲区地址
    mov di, ards_buf            ; @di [in]: ds 指向缓冲区起始地址

    ; --- 使用 0x15 中断的 0xe820 子功能遍历所有内存 ---
    .e820_get_memory:
        mov eax, 0x0000e820    ; @eax [in]: 子功能号
        mov ecx, 0x14          ; @ecx [in]: 一个 ARDS 结构 20 byte
        mov edx, 0x534d4150    ; @edx [in]: 固定签名
        
        int 0x15
        jc .e820_failed_and_try_e801    ; 尝试下一个子功能

        add di, cx            ; 递增循环变量 di
        inc word [ards_nr]    ; 计数
        cmp ebx, 0            ; 循环终止条件
        jne .e820_get_memory  ; 结果不为 0

        ; 计算内存容量
        mov cx, [ards_nr]        ; cx: 结构体数量
        mov ebx, ards_buf      ; ebx: 结构体起始地址
        xor edx, edx           ; 清零，保存内存容量

    .e820_calculate_max_memory:
        mov eax, [ebx]         ; offset = 0: BaseAddrLow 
        add eax, [ebx+8]       ; offset = 8: LengthLow
        add ebx, 20
        cmp edx, eax
        jge .e820_next_ards
        mov edx, eax            ; eax 为最终内存总容量

    .e820_next_ards:
        loop .e820_calculate_max_memory
        jmp .get_memory_succeed


    ; --- 使用 0x15 中断的 0xe810 子功能遍历所有内存 ---
    .e820_failed_and_try_e801:
        mov ax, 0xe801
        
        int 0x15
        jc .e810_failed_and_try_88

        ; 1. 先算出低 15 MB 内存
        mov cx, 0x400
        mul cx
        shl edx, 16
        and eax, 0x0000_ffff
        or edx, eax
        add edx, 0x100000
        mov esi, edx

        ; 2. 再将 16 MB 以上内存转换为 byte 单位
        xor eax, eax
        mov ax, bx
        mov ecx, 0x10000
        mul ecx 
        mov edx, esi
        add esi, eax
        jmp .get_memory_succeed



    ; --- 使用 0x15 中断的 0x88 子功能遍历所有内存 ---
    .e810_failed_and_try_88:
        mov ax, 0x88
        int 0x15
        jc .error_and_halt
        and eax, 0x0000ffff

        mov cx, 0x400
        mul cx
        shl edx, 16
        or edx, eax
        add edx, 0x100000

    .error_and_halt:
        jmp $

    .get_memory_succeed:
        mov [total_memory], edx

    ; --- 准备进入保护模式 ---

    ; --- 1. 打开 A20 地址线 ---
    ; 启用 A20 地址线，取消地址回绕
    in al, 0x92
    or al, 0000_0010b
    out 0x92, al

    ; --- 2. 加载 GDT ---
    lgdt [gdt_ptr]

    ; --- 3. cr0 第 0 位置 1
    ; 打开保护模式
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax

    jmp dword SELECTOR_CODE:p_mode_start    ; 刷新流水线 + 段描述符缓冲寄存器

[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax                  
    mov esp, LOADER_STACK_TOP    ; 初始化栈指针
    mov ax, SELECTOR_VIDEO
    mov gs, ax
    
    mov byte [gs:320], 'H'
    
    jmp $


