#ifndef __LIB_IO_H
#define __LIB_IO_H
#include "stdint.h"

/* 向端口写一个字节 */
static inline void outb(uint16_t port, uint8_t data) {
    asm volatile("outb %b0, %w1" : : "a"(data), "Nd"(port));
}

/* 将 addr 起始处的 word_cnt 个字节写入端口 */
static inline void outsw(uint16_t port, const void *addr, uint32_t word_cnt) {
    asm volatile("cld; rep outsw" : "+S"(addr), "+c"(word_cnt): "d"(port));
}

/* 从端口读入一个字节 */
static inline uint8_t inb(uint16_t port) {
    uint8_t data;
    asm volatile("inb %wl, %b0" : "=a"(data): "Nd"(port));
    return data;
}

/* 从端口读入 word_cnt 个字节写入 addr 起始的地址 */
static inline void insw(uint16_t port, void *addr, uint32_t word_cnt) {
    asm volatile("cld; rep insw" : "+D"(addr), "+c"(word_cnt) : "d"(port) : "memory");
}

#endif