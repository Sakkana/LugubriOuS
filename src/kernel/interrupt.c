#include "interrupt.h"
#include "stdint.h"
#include "global.h"
#include "io.h"
#include "print.h"

#define PIC_M_CTRL  0x20    // 主片控制端口
#define PIC_M_DATA  0x21    // 主片数据端口
#define PIC_S_CTRL  0xa0    // 从片控制端口
#define PIC_S_DATA  0xa1    // 从片数据端口

#define IDT_DESC_CNT    0x21    // 中断处理程序个数

// 中断门描述符结构
struct gate_desc {
    uint16_t    func_offset_low_word;
    uint16_t    selector;
    uint8_t     dcount;
    uint8_t     attribute;
    uint16_t    func_offset_high_word;
};

// 中断描述符表
static struct gate_desc idt[IDT_DESC_CNT];

// 创建中断处理函数
static void make_idt_desc(struct gate_desc* p_gdesc, 
                          uint8_t attr, 
                          intr_handler function);

// 中断处理函数入口数组
extern intr_handler intr_entry_table[IDT_DESC_CNT];

// 初始化 8259A
static void pic_init() {
    // 初始化主片
    outb(PIC_M_CTRL, 0x11);     // ICW1: 边沿触发，级联8259，需要 ICW4
    outb(PIC_M_DATA, 0x20);     // ICW2: 起始中断向量号为 0x20，IR[0-7] 为 0x20-0x27
    outb(PIC_M_DATA, 0x04);     // ICW3: IR2 接从片
    outb(PIC_M_DATA, 0x01);     // ICW4: 8086 模式，正常 EOI

    // 初始化从片
    outb(PIC_S_CTRL, 0x11);     // ICW1: 边沿触发，级联8259，需要 ICW4
    outb(PIC_S_DATA, 0x28);     // ICW2: 起始中断向量号为 0x28，IR[8-15] 为 0x28-0x2f
    outb(PIC_S_DATA, 0x02);     // ICW3: 设置从片连接到主片的 IR2 引脚
    outb(PIC_S_DATA, 0x01);     // ICW4: 9096 模式，正常 EOI

    // 打开主片上的 IR0，只接受时钟中断
    outb(PIC_M_DATA, 0xfe);
    outb(PIC_S_DATA, 0xff);

    put_str("pic_init done!\n");
}

static void make_idt_desc(struct gate_desc* p_gdesc, 
                          uint8_t attr, 
                          intr_handler function) {
    p_gdesc->func_offset_low_word = (uint32_t)function & 0x0000ffff;
    p_gdesc->selector = SELECTOR_K_CODE;
    p_gdesc->dcount = 0;
    p_gdesc->attribute = attr;
    p_gdesc->func_offset_high_word = ((uint32_t)function & 0xffff0000) >> 16;
}

// 初始化中断描述符
static void idt_desc_init() {
    for (int i = 0; i < IDT_DESC_CNT; ++ i) {
        make_idt_desc(&idt[i], IDT_DESC_ATTR_DPL0, intr_entry_table[i]);
    }
    put_str("idt_desc_init done!\n");
}

// 初始化中断工作
void idt_init() {
    put_str("idt_init start\n");
    idt_desc_init();    // 初始化中断描述符表
    pic_init();         // 初始化 8259A

    // 加载 idt
    uint64_t idt_operand = ((sizeof(idt) - 1) | (uint64_t)((uint32_t)idt << 16));
    asm volatile("lidt %0" : : "m"(idt_operand));
    put_str("idt_init done!\n");
}