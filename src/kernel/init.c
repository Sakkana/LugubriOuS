#include "init.h"
#include "interrupt.h"
#include "print.h"

// 初始化所有模块
void init_all() {
    put_str("init_all\n");
    idt_init();
}