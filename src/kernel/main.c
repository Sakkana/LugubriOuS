#include "print.h"
#include "init.h"

void ludovico_main() {
	put_str("Kernel is booting.\n");
	init_all();
	asm volatile("sti");	// 临时开中断
	while(1);
}