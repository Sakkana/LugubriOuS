; 主引导程序
;--------------------------------------------------
%include "boot.inc"
SECTION MBR vstart=0x7c00 ;起始地址编译在0x7c00
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00
    mov ax, 0xb800
    mov gs, ax
    ;这个时候 ds = es = ss = 0 栈指针指向MBR开始位置


    ;ah = 0x06 al = 0x00 想要调用int 0x06的BIOS提供的中断对应的函数 即向上移动即完成清屏功能
    ;cx dx 分别存储左上角与右下角的左边 详情看int 0x06函数调用
    mov ax,0x600 
    mov bx,0x700
    mov cx,0            ; 左上角
    mov dx,0x184f       ; 右下角
    
    ;调用BIOS中断
    int 10h

    mov byte [gs:0x00], 'M'
    mov byte [gs:0x01], 0xa4

    mov byte [gs:0x02], 'B'
    mov byte [gs:0x03], 0xa4

    mov byte [gs:0x04], 'R'
    mov byte [gs:0x05], 0xa4

    ; 模拟手动传参
    mov eax, LOADER_START_SECTOR    ; 起始扇区 lba 地址
    mov bx, LOADER_BASE_ADDR        ; 写入地址，loader 会存在 0x900
    mov cx, 4                       ; 待读入扇区数 4 -> loader 超过 512 byte
    call rd_disk_m_16               ; 下面读取程序的起始部分 (loader)

    jmp LOADER_BASE_ADDR

rd_disk_m_16:
; ---
; 读取磁盘 n 个扇区
; ---
    ; eax = lba 扇区号
    ; bx = 数据要写入的内存地址
    ; cx = 读入的扇区数

    ; 备份
    mov esi, eax
    mov di, cx

; ---
; 1. 设置要读取的扇区数
; ---

    mov dx, 0x1f2   ; sector count 寄存器
    mov al, cl      ; 待读入扇区数写入 ax
    out dx, al      ; 读取的扇区数

    mov eax, esi    ; 恢复 ax

; ---
; 2. 将 LBA 地址存入 0x1f3 ~ 0x1f6
; ---

    ; LBA 地址 7~0 位写入端口 0x1f3
    mov dx, 0x1f3   ; LBA low 寄存器
    out dx, al

    ; LBA 地址 15~8 位写入端口 0x1f4
    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4   ; LBA mid 寄存器
    out dx, al

    ; LBA 地址 23~16 位写入端口 0x1f5
    shr eax, cl
    mov dx, 0x1f5   ; LBA high 寄存器
    out dx, al

    ; LBA 地址 27~24 位写入端口 0x1f6
    shr eax, cl
    and al, 0x0f
    or al, 0xe0     ; 7~4 位为 1110，表示 lba 模式
    mov dx, 0x1f6   ; device 寄存器
    out dx, al

; ---
; 3. 向 0x1f7 端口写入读命令:0x20
; ---

    mov dx, 0x1f7   ; Status 寄存器
    mov al, 0x20    ; read sector 命令
    out dx, al

; ---
; 4. 检测硬盘状态
; ---

.not_ready:
    nop
    in al, dx
    and al, 0x88    ; 第三位=1表示硬盘控制器准备好数据传输，第七位=1表示硬盘繁忙
    cmp al, 0x08
    jnz .not_ready  ; 若没有准备好，继续等待

; ---
; 5. 从端口 0x1f0 读取数据
; ---

    mov ax, di      ; ax = 要读取的扇区数
    mov dx, 256
    mul dx
    mov cx, ax
    mov dx, 0x1f0

.go_on_read:
    in ax, dx
    mov [bx], ax
    add bx, 2
    loop .go_on_read
    ret

    times 510 - ($ - $$) db 0 
    db 0x55,0xaa
