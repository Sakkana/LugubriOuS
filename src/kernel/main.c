#include "print.h"
#include "init.h"
#include "memory.h"
// #include "debug.h"

void ludovico_main(void) {
	put_str("Ludovico Kernel is booting...\n");
	init_all();
	// asm volatile("sti");	// 临时开中断

	void *addr = get_kernel_pages (3);
	put_str ("\nget_kernel_page start vaddr is: ");
	put_int ((uint32_t)addr);
	put_char('\n');

	while(1);
}