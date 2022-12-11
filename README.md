# myOS



### 通用寄存器



#### 段寄存器

##### cs

**代码段**寄存器：Code Segment

##### ds

**数据段**寄存器：Data Segment

指出**当前程序使用的数据**所存放**段的最低地址**，即存放数据段的**段基址**。

##### es、fs、gs

**附加段**寄存器：Extra Segment

存放当前执行程序中一个**辅助数据段**的**段地址**。 

##### ss

**栈段**寄存器：Stack Segment





##### si, di

功能和 **bx** 相近， 但是这两个不能分成两个8位寄存器使用



> 



##### CRx

控制寄存器系列，展示 CPU 内部状态，控制 CPU 运行机制。

`cr0 寄存器` 的第 0 位： `PE` 位，用于打开 A20 地址线，这是实模式和保护模式的开关。

`cr3 寄存器`：目录基址寄存器 PDBR (Page Directory Base Register)，用于存放页表的物理地址。



### sti, cli (可屏蔽中断 & 不可屏蔽中断)

可屏蔽中断和内中断处理差不多，只不过是来自CPU外部。

如果CPU要处理可屏蔽中断，需要将 IF = 1。

如果 IF = 0，进入中断处理程序后，禁止其他的可屏蔽中断。

IF 设置方法：

> sti -> IF = 1
>
> cli -> IF = 0
>
> 或许对应的是 set interupt 和 clear interupt （我猜的，没有考证过）



### 端口读写

只能使用 ax 或者其低 8 位 al 来存放从端口读入或者写出的相互据。

8 位端口用 al，16 位端口用 ax。

示例：

```80x86
; 0 ~ 255 号端口
in al, 0x20
out 0x20, al

; 256 ~ 65535 号端口
mov dx, 0x3f8	; 0x3f8 是 1016 号端口，具体是干啥的我不知道
in al, dx
out dx, al
```







### 键盘中断

键盘中断会产生扫描码，扫描码会传入硬件的寄存器中，该寄存器对于 CPU 来说端口为 `0x60`。

读取该键盘输入的扫描码：

```80x86
in al, 0x60
```



 端口 `0x60` 和 `0x61` 与PC中的键盘控制器通信。 端口0x60包含按下的键，0x61具有状态位。 

 切换状态端口的 **高位信号** 表示您已获得键盘输入并希望下一个键盘输入。 

 端口 0x20 是中断控制器，您可以在其中确认已处理中断。 



### 启动

##### 0xFFFF0 （BIOS 入口地址）

开机一瞬间， CPU 的 cs:ip = `0xF000: 0xFFF0`

cs << 4 + ip = 0xFFFF0，这是内存最顶端，**BIOS 入口地址**



##### 0xfe05b （BIOS 代码地址）

0xFFFF0 ~ 0xFFFFF：共 16 byte，存储了一条跳转指令 `jmp f000: e05b`，会跳转到 `0xfe05b`

这是 BIOS 代码真正开始的地方

BIOS 开始检测内存，显卡等外部设备信息，初始化硬件，在 0x000 ~ 0x3FF 处建立数据结构，中断向量表，填写中断例程

内存最低端 `0x0 ~ 0x3ff` 存放中断向量表



##### 0x7c00 （主引导程序 MBR）

BIOS 的最后一项工作是校验启动盘中 `0盘0道1扇区` 的内容。

如果该扇区末尾是魔法数字 `0x55` 和 `0xaa`，BIOS 就认为这个扇区确实存在可执行程序 (`MBR`)，便跳转到地址 `0x7c00` 处执行。

`jmp 0: 0x7c00` 后，cs 便从 F000 修改成了 0。

MBR 是我们目前第一个能够控制的程序。



##### MBR (Main Boot Record) 

位于磁盘最开始的扇区。

512 字节，太小，无法为内核准备好所有的环境 ---> jmp 到另一个地址加载 loader

> 446 字节引导程序及参数
>
> 64 字节分区表，共 4 个分区，每个分区 16 字节
>
> 2 字节结束标记 `0x55` 和 `0xaa`

BIOS 将系统控制权交给 MBR，MBR 遍历所有的分区，找到一个合适的将控制权移交给他（次引导程序，通常是操作系统加载器）。

最终这个加载器将控制权移交给操作系统。

> ##### MBR 分区
>
> 在 MBR 中的某个分区安装操作系统，就要将该分区设置为 `活动分区`。
>
> 活动分区的标志：开头的一个字节为 `0x80`。否则为 0。
>
> MBR 最主要的任务是加载操作系统，那么首先要加载操作系统内核。
>
> 因此，**内核加载器（OBR, OS Boot Record）**往往写在固定的地址：各分区最开始的扇区。
>
> 之后，这里的代码将 jmp 到真正的操作系统引导程序。



##### Loader

Loader 是为 OS 内核的加载做一系列初始化工作的软件。

MBR 负责把 Loader 从磁盘的第二个扇区读出来，写到内存的 0x9000 这个地址处。

Loader 负责做一些初始化的工作，比如定义一些数据结构（全局描述符表等）。

尽量把 Loader 放在低地址，有利于后面内核的增长



### 编写 MBR

BIOS 的最后一项工作，就是检查启动盘的 `0 盘 0 道 0 扇区`。

如果这个扇区 512 byte 的最后两个字节是 `0x55` 和 `0xaa`，那么 BIOS 就认为改善去中确实存在可运行的程序（MBR），然后就跳过去。

MBR 从硬盘读取 Loader，再跳过去。



### 进入保护模式

#### 什么是保护模式

保护模式这个概念最开始在 80286 CPU 中出现。

实模式为 32 位的 CPU 工作在 16 位模式下，寄存器为 16 位，一个段最多访问 64KB 的内存。

使用 `段基址 + 段偏移` 可以达到 20 位的寻址能力，访问 1MB 的内存。

CPU 发展到 32 位寄存器后，可以访问 4 GB 的内存。

> 通用寄存器，sp，标志寄存器都扩展到了 32 位
>
> 但是段寄存器还是 16 位



#### 地址回绕 & 打开 A20 GATE

8086 的 16 位 CPU 下，一共只有 A0 ~ A19 共 20 根地址线。

对于超过 `0 `~ `2^20-1` 的地址访问 8086 的做法是采用地址回绕，也就是无符号数的溢出，相当于模一个 1MB 继续从 0 向上增长。

而 80286 有 24 根地址线，因此可以访问超过 1MB 的物理内存。

前面提到实模式这个概念是在 80286 中出现的，因此若 80286 想像 8086 一样工作在 16 位的模式下，只访问 20 位地址空间，那么第 21 根地址线是不可以使用的。

因此，生产商用键盘控制器上的输出线来控制第 21 根地址线的使能，也就是 A20Gate。

* A20Gate = On：访问 0x100000 ~ 0x10ffef，直接访问
* A20Gate = On：访问 0x100000 ~ 0x10ffef，地址回绕



打开方式：

1. 打开 A20
2. 加载全局描述符表
3. 将 cr0 的 PE 位置 1

> 代码：
>
> mov eax, cr0
>
> or eax, 0x0000_0001
>
> mov cr0, eax



#### 模式反转

* [16 bits]：告诉编译器，将下面的代码编译成 16 位

* [32 bits]：告诉编译器，将下面的代码编译成 32 位

编译器会在当前模式的指令前加上反转前缀

* 操作数反转前缀：0x66
* 寻址方式反转前缀：0x67





#### 全局描述符表

是保护模式下 `内存段` 的登记表，其中每一个表项称为 `段描述符`。

该全局描述符表很大，存储在内存中，由 48 位 `GDTR` 寄存器指向该表的起始地址。

> GDTR 寄存器格式
>
> | GDT 内存起始地址 | GDT 界限 |
>
> |-----------32 位----------|----16位---|
>
> GDT 界限是 GDT 的大小。
>
> 16 位意味着 GDT 最大为 2^16 byte，也就是 65536 byte
>
> 每个描述符 8 byte，因此一个 GDT 可以放 2^16 / 2^3 = 2^13 = 8912 个段描述符

在这种模式下，段寄存器里保存的不是 `段基址`，而是 `选择子`。该选择子是个整型，用于索引全局描述符表中的表项。

CPU 会使用 `段描述符缓冲寄存器` 缓存段描述符，因为频繁访问内存中的全局描述符表开销非常大。

在 80386  CPU 中，地址总线和通用寄存器都是 32 位，因此，任何一个段都可以直接扫射 4GB 的内存 ---> 平坦模式。



##### 如何描述一个内存段？一个段描述符长什么样？

一个段描述符占 8 byte。

* 特权级属性：DPL
* 段基址：32 bits
* 段界限：20 bits，该段扩展的最值，如数据段、代码段向上生长，栈向下生长，其扩展单位由 G 位指定，通常为 1 byte 或 4 KB
  * 一个段的实际边界值：(段描述符界限 + 1) * (段界限单位) - 1
  * G = 0：单位为 1 byte
  * G = 1：单位为 4KB
* type：4 bits，内存段或门的子类型
  * 系统段的 S 字段含义比较复杂
  * 非系统段
  * 代码段：X | C | R | A  ---> （Executable | Conforming | Readable | Accessed ）
  * 数据段：X | E | W | A ---> （Executable | Extend | Writable | Accessed）
* S：段的类型
  * S = 0：系统段
  * S = 1：用户段
* P：Present
  * P = 1：该段在内存中
  * P = 0：该段不在内存中



#### 选择子

选择子专门用于在 GDT 中索引段描述符。

由于段基址已经放在了 GDT 中，因此段寄存器放段基址没有任何意义，况且段描述符也会缓冲在段描述符缓冲寄存器中。

段寄存器是 16 位，因此选择子也是 16 位。

* RPL：请求特权级属性，分为 00, 01, 10, 11，分别表示四种特权级
* TI：Table Indicator，表示该描述符在 LDT 中还是在 GDT 中，用于选择子去索引
* idx：描述符在该表中的下标，正好是 13 位，和 GDT 界限 16 位，一个描述符 3 位正好吻合

> 选择子格式
>
> |              IDX             |  TI  |      RPL     |
>
> |-----------13 位---------|1 位|-----2 位----|

保护模式使用 32 位地址线和 32 位寄存器，因此不需要段基址 << 4 + 段偏移。

GDT 第 0 个描述放置不用，防止忘记初始化选择子默认索引到第 0 个描述符。



### 获取物理内存

原理：在实模式中利用BIOS中断0x15 -> 调用硬件API

使用方式：将0x15的子功能号放入寄存器 `ax` 或者 `eax`

子功能：

`0xE820`：返回内存布局，内容多，操作复杂

`0xE801`：直接返回内存容量，分别检测低 15MB 和 16MB ~ 4GB

`0x88`：最多检测64MB





### 分页

##### 线性地址 & 物理地址

线性地址就是 `段基址 + 段内偏移`，这是软件看到的。

在传统分段方式上，默认了 `线性地址 == 物理地址`。

分页打破了这一规则，允许程序看到的线性地址连续，但是物理地址不连续。

媒介就是 `页表`。



分段是 Intel IA32 架构骨子里的东西，只能改革，不能革命。

因此，分页是基于分段的。

这个分页机制相当于一个开关，打开后就启用分页，页表检索，地址转换。

如果没打开，就直接原来的模式，即物理地址 == 线性地址。

```python
linear_addr = segment base + segment offset
if (paging == True):
    physical_addr = page_table[linear_addr]
else:
    physical_addr =linear_addr
```



保护模式下寻址空间是 4GB，指的是线性地址。

分页机制的核心：通过页表的映射，将 **连续的线性地址** 转换为任意 **不连续的物理地址**。



##### 不分页

32 位下物理地址 4 GB。

一个页表项 4 byte，光是页表就要占用 16 GB。

太大了。



##### 一级页表

| --------- 20 位页表索引 ---------| --12 位页内偏移 -- |

将物理内存划分为一页 4 KB 的页。

4 GB 内存花费 4 GB / 4 KB = 1 M 个页，需要 1M 个 PTE。

因此页表只需要 1 M 个 PTE，占用 1 M x 4 byte = 4 MB。

一个页 4 KB，也就是 0x100，因此所有的页起始地址都是 4KB 对其，结尾都是三个 0。

需要将页表基址加载到 `控制寄存器 cr3 中`。



##### 二级页表

> 其实和 mysql 里的 B+ 树差不多一个道理，从叶子节点开始不断合并，向上生长出父亲，父亲满了再向上生长出爷爷。

一个页 4KB，一个 PTE 4 byte，因此一个页可以放 1K 个 PTE，也就是可以指向 1K 个物理页。

因此指向 4 GB / 4 KB = 1 MB 个物理页需要 1MB / 1K = 1K 个页表（第二级页表）。

将这 1K 个页表再装起来，得到一个 1K x 4 byte = 4 KB 的页表（第一级页表，也被称为页目录）。

这就是多级页表。



##### PTE 的结构

如前面所述，一个页表项占用 4 byte。

> 页目录项：
>
> | 物理地址 20 位 | AVL | G |   0   | D | A | PCD | PWT | US | RW | P |
>
> 页表项：
>
> | 物理地址 20 位 | AVL | G | PAT | D | A | PCD | PWT | US | RW | P |

物理页的地址都是 20 位是因为，每个页都是 4 KB 对其，因此每个物理页的起始地址都是以4 KB 为倍数的。

况且确切的物理地址会根据 PTE 中的 20 位加上虚拟地址中的 12 位页内偏移凑齐 32 位地址。



##### 开启分页机制

1. 准备好页目录和页表
2. 将页表地址写进控制寄存器 cr3
3. 寄存器 cr0 的 PG 为置 1 （PG 是第最后一位，32 位，用 mask = 0x8000_0000 就可以饿了）



### 加载操作系统内核





### 编写中断处理程序





### 内存管理





### 实现内核线程







### 多线程调度





### 键盘输入输出





### 实现用户进程





### 磁盘驱动程序





### 文件系统





