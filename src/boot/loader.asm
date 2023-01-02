%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR 		           ;是个程序都需要有栈区 我设置的0x600以下的区域到0x500区域都是可用空间 况且也用不到
jmp loader_start                     		   	       ;下面存放数据段 构建gdt 跳跃到下面的代码区 


    GDT_BASE:           dd 0x00000000          		   ;刚开始的段选择子0不能使用 故用两个双字 来填充
   		                dd 0x00000000 
    
    CODE_DESC:          dd 0x0000FFFF         		   ;FFFF是与其他的几部分相连接 形成0XFFFFF段界限
    		            dd DESC_CODE_HIGH4
    
    DATA_STACK_DESC:    dd 0x0000FFFF
  		                dd DESC_DATA_HIGH4
    		       
    VIDEO_DESC:         dd 0x80000007         		   ;0xB8000 到0xBFFFF为文字模式显示内存 B只能在boot.inc中出现定义了 此处不够空间了 8000刚好够
                        dd DESC_VIDEO_HIGH4     	   ;0x0007 (bFFFF-b8000)/4k = 0x7
                 
    GDT_SIZE             equ $ - GDT_BASE              ;当前位置减去GDT_BASE的地址 等于GDT的大小
    GDT_LIMIT       	 equ GDT_SIZE - 1   	       ;SIZE - 1即为最大偏移量
    
    times 59 dq 0                             	       ;预留59个 define double四字型 8字描述符
    times 5 db 0                                       ;为了凑整数 0x800 导致前面少了三个
    
    total_mem_bytes  dd 0
    
    gdt_ptr           dw GDT_LIMIT			           ;gdt指针 2字gdt界限放在前面 4字gdt地址放在后面 lgdt 48位格式 低位16位界限 高位32位起始地址
    		          dd GDT_BASE
    		       
    ards_buf times 244 db 0                             ;buf  记录内存大小的缓冲区
    ards_nr dw 0					                    ;nr 记录20字节结构体个数  计算了一下 4+2+4+244+2=256 刚好256字节
    
    SELECTOR_CODE        equ (0X0001<<3) + TI_GDT + RPL0    ;16位寄存器 4位TI RPL状态 GDT剩下的选择子
    SELECTOR_DATA	     equ (0X0002<<3) + TI_GDT + RPL0
    SELECTOR_VIDEO       equ (0X0003<<3) + TI_GDT + RPL0   
    
loader_start:
    
    mov sp,LOADER_BASE_ADDR                                   ;先初始化了栈指针
    xor ebx,ebx                                               ;异或自己 即等于0
    mov ax,0                                       
    mov es,ax                                                 ;心有不安 还是把es给初始化一下
    mov di,ards_buf                                           ;di指向缓冲区位置

    .e820_mem_get_loop:
        mov eax,0x0000E820                                    ;每次都需要初始化
        mov ecx,0x14
        mov edx,0x534d4150
        
        int 0x15                                               ;调用了0x15中断
        jc  .e820_failed_so_try_e801                           ;这时候回去看了看jc跳转条件 就是CF位=1 carry flag = 1 中途失败了即跳转
        
        add di,cx							                   ;把di的数值增加20 为了下一次作准备
        inc word [ards_nr]
        cmp ebx,0
        jne .e820_mem_get_loop                                  ;直至读取完全结束 则进入下面的处理时间
        
        mov cx,[ards_nr]                                        ;反正也就是5 cx足以
        mov ebx,ards_buf
        xor edx,edx

    .find_max_mem_area:
        mov eax,[ebx]						 ;我也不是很清楚为什么用内存上限来表示操作系统可用部分
        add eax,[ebx+8]                                            ;既然作者这样用了 我们就这样用
        add ebx,20    						 ;简单的排序
        cmp edx,eax
        jge .next_ards
        mov edx,eax

    .next_ards:
        loop .find_max_mem_area
        jmp .mem_get_ok
        
    .e820_failed_so_try_e801:                                       ;地址段名字取的真的简单易懂 哈哈哈哈 
        mov ax,0xe801
        
        int 0x15
        jc .e801_failed_so_try_88
    
        ;1 先算出来低15MB的内存    
        mov cx,0x400
        mul cx                                                      ;低位放在ax 高位放在了dx
        shl edx,16                                                  ;dx把低位的16位以上的书往上面抬 变成正常的数
        and eax,0x0000FFFF                                          ;把除了16位以下的 16位以上的数清零 防止影响
        or edx,eax                                                  ;15MB以下的数 暂时放到了edx中
        add edx,0x100000                                            ;加了1MB 内存空缺 
        mov esi,edx
        
        ;2 接着算16MB以上的内存 字节为单位
        xor eax,eax
        mov ax,bx
        mov ecx,0x10000                                              ;0x10000为64KB  64*1024  
        mul ecx                                                      ;高32位为0 因为低32位即有4GB 故只用加eax
        mov edx,esi
        add edx,eax
        jmp .mem_get_ok
    
    .e801_failed_so_try_88:
        mov ah,0x88
        
        int 0x15
        jc .error_hlt
        
        and eax,0x0000FFFF
        mov cx,0x400                                                 ;1024
        mul cx
        shl edx,16
        or edx,eax 
        add edx,0x100000

    .error_hlt:
        jmp $

    .mem_get_ok:
        mov [total_mem_bytes],edx


; --- 进入保护模式 ---
    
    in al,0x92                 ;端口号0x92 中 第1位变成1即可
    or al,0000_0010b
    out 0x92,al
    
    lgdt [gdt_ptr]
    
    mov eax,cr0                ;cr0寄存器第0位设置位1
    or  eax,0x00000001              
    mov cr0,eax
      
    jmp dword SELECTOR_CODE:p_mode_start
 
 [bits 32]
 p_mode_start: 
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax
    
    mov byte [gs:160],'X'

; --- 加载内核到缓冲区 ---

    mov eax, KERNEL_START_SECTOR    ; kernel 所在的扇区号
    mov ebx, KERNEL_BIN_BASE_ADDR   ; kernel 在内存中的布局
    mov ecx, 200                    ; 直接读 200 个扇区。200 x 512 byte

    call rd_disk_m_32

; --- 启动分页 ---
    call setup_page
    							         ;这里我再把gdtr的格式写一下 0-15位界限 16-47位起始地址
    sgdt [gdt_ptr]                                             ;将gdt寄存器中的指 还是放到gdt_ptr内存中 我们修改相对应的 段描述符
    mov ebx,[gdt_ptr+2]                                        ;32位内存先倒出来 为的就是先把显存区域描述法的值改了 可以点开boot.inc 和 翻翻之前的段描述符
                                                               ;段基址的最高位在高4字节 故
    or dword [ebx+0x18+4],0xc0000000
    add dword [gdt_ptr+2],0xc0000000                            ;gdt起始地址增加 分页机制开启的前奏
    
    add esp,0xc0000000                                         ;栈指针也进入高1GB虚拟内存区
    
    mov eax,PAGE_DIR_TABLE_POS
    mov cr3,eax
    
    ; 修改 cr0 寄存器最高位，启用分页
    mov eax,cr0
    or eax,0x80000000
    mov cr0,eax
    
    lgdt [gdt_ptr]
    
    mov eax,SELECTOR_VIDEO
    mov gs,eax
    mov byte [gs:320],'V'

    ; jmp $       ; 跳到内核
    jmp SELECTOR_CODE: boot_kernel


boot_kernel:
    call init_kernel
    mov esp, 0xc009f00
    jmp KERNEL_ENTER_POINT

; --- 创建页表 ---
setup_page:
    mov ecx,0x1000                                             ;循环4096次 将页目录项清空 内存清0
    mov esi,0                                                   
 .clear_page_dir_mem:                                          ;dir directory 把页目录项清空
    mov byte [PAGE_DIR_TABLE_POS+esi],0
    inc esi
    loop .clear_page_dir_mem
    
 .create_pde: 
    mov eax,PAGE_DIR_TABLE_POS				  ;页目录项 起始位置
    add eax,0x1000                                              ;页目录项刚好4k字节 add eax即得第一个页表项的地址
                                                                ;接下来我们要做的是 把虚拟地址1M下和3G+1M 两部分的1M内存在页目录项中都映射到物理地址0-0XFFFFF
    or  eax, PG_P | PG_RW_W | PG_US_U                           ;哦 悟了 哈哈哈 这里设置为PG_US_U 是因为init在用户进程 如果这里设置成US_S 这样子连进内核都进不去了
     
    mov [PAGE_DIR_TABLE_POS+0x0],eax                             ;页目录项偏移0字节与偏移0xc00 对应0x 一条页目录项对应2^22位4MB 偏移由前10位*4字节得到 可自己推算一下
    mov [PAGE_DIR_TABLE_POS+0xc00],eax                        
    sub eax,0x1000      
    
    mov [PAGE_DIR_TABLE_POS+4092],eax                           ;虚拟内存最后一个目录项 指向页目录表自身 书上写的是为了动态操纵页表 我也不是很清楚 反正有用 先放放

;这里就创建了一页页表    
    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x1000
    mov ecx,256
    mov esi,0
    mov ebx,PG_P | PG_RW_W | PG_US_U 
    
 .create_kernel_pte:           
    mov [eax+esi*4],ebx
    inc esi
    add ebx,0x1000
    loop .create_kernel_pte 
    
    
;这里对于我们这里填写的目录项所对应的页表 页表中我们还没填写的值
;为了实现 真正意义上的 内核空间被用户进程完全共享
;只是把页目录与页表的映射做出来了 

    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x2000       					   ;eax此时处于第二个页表
    or  eax,PG_P | PG_RW_W | PG_US_U
;这里循环254次可以来分析一下 我们这里做的是 0xc0 以上部分的映射    0xc0 对应的是第768个页表项 页表项中一共有 2^10=1024项
;第1023项我们已经设置成 映射到页目录项本身位置了 即1022 - 769 +1 = 254
    mov ebx,PAGE_DIR_TABLE_POS
    mov ecx,254						  
    mov esi,769
        
 .create_kernel_pde:
    mov [ebx+esi*4],eax
    inc esi
    add eax,0x1000
    loop .create_kernel_pde 
    
    ret



; -- 初始化内核 ---
init_kernel:
    ; 寄存器全部清零
    xor eax, eax
    xor ebx, ebx    ; 记录程序头表地址
    xor ecx, ecx    ; 程序头表中的 entry 数量
    xor edx, edx    ; 程序头的尺寸，即 e_phentsize

    ;这里稍微解释一下 因为0x70000 为 64kb * 7 = 448kb 而我们的内核映射区域是 4MB 而在虚拟地址4MB以内的都可以当作1:1映射
    mov ebx,[KERNEL_BIN_BASE_ADDR+28]                           ; elf offset 28，程序头表的量
    add ebx,KERNEL_BIN_BASE_ADDR                               ;ebx当前位置为程序段表
    mov dx,[KERNEL_BIN_BASE_ADDR+42]		                 ;获取程序段表每个条目描述符字节大小
    mov cx,[KERNEL_BIN_BASE_ADDR+44]                         ;一共有几个段
    
     
 .get_each_segment:
    cmp dword [ebx+0], PT_NULL                                  ; 这里没有程序段，可以忽略，定义在 Phdr (program header) 中
    je .PTNULL                                                 ;空即跳转即可 不进行mem_cpy
    
    mov eax,[ebx+8]
    cmp eax,0xc0001500
    jb .PTNULL
    
        
    push dword [ebx+16]                                        ;ebx+16在存储的数是filesz  可以翻到Loader刚开始
                                                               
    mov eax,[ebx+4]                                            
    add eax,KERNEL_BIN_BASE_ADDR
    push eax                                                   ;p_offset 在文件中的偏移位置    源位置         
    push dword [ebx+8]                                         ;目标位置
     
    call mem_cpy
    add esp,12                                                 ;把三个参数把栈扔出去 等于恢复栈指针
    
 .PTNULL:
    add  ebx,edx                                               ;edx是一个描述符字节大小
    loop .get_each_segment                                     ;继续进行外层循环    
    ret
                                        
mem_cpy:
    cld                                                        ;向高地址自动加数字 cld std 向低地址自动移动
    push ebp                                                   ;保存ebp 因为访问的时候通过ebp 良好的编程习惯保存相关寄存器
    mov  ebp,esp 
    push ecx                                                   ;外层循环还要用 必须保存 外层eax存储着还有几个段
    
                                                               ;分析一下为什么是 8 因为进入的时候又重新push了ebp 所以相对应的都需要+4
                                                               ;并且进入函数时 还Push了函数返回地址 所以就那么多了
    mov edi,[ebp+8]                                            ;目的指针 edi存储的是目的位置 4+4
    mov esi,[ebp+12]                                           ;源指针   源位置             8+4
    mov ecx,[ebp+16]                                           ;与Movsb好兄弟 互相搭配      12+4
    
    
    rep movsb                                                  ;一个一个字节复制
       
    pop ecx 
    pop ebp
    ret



rd_disk_m_32:
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
    mov [ebx], ax
    add ebx, 2
    loop .go_on_read
    ret