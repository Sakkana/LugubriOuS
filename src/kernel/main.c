#include "print.h"
#include "init.h"
#include "debug.h"	

void ludovico_main(void) {
	put_str("Ludovico Kernel is booting...\n");
	init_all();
	// asm volatile("sti");	// 临时开中断
	while(1);
}