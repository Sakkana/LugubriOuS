#ifndef __MEMORY_KERNEL_H
#define __MEMORY_KERNEL_H
#include "stdint.h"
#include "bitmap.h"

// 虚拟内存池
struct virtual_addr {
    struct bitmap   vaddr_bitmap;
    uint32_t        vaddr_start;
};

extern struct pool kernel_pool;
extern struct pool user_pool;

void mem_init(void);


#endif