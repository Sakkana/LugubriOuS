#include "bitmap.h"
#include "string.h"
#include "stdint.h"
#include "print.h"
#include "interrupt.h"
#include "debug.h"

// 初始化位图
void bitmap_init(struct bitmap *btmp) {
    memset(btmp->bits, 0, btmp->btmap_bytes_len);
}

// 判断 bit_idx 是否为 1
int bitmap_scan_test(struct bitmap *btmp, uint32_t bit_idx) {
    // 该 bit_idx 在第 bit_byte 个字节
    uint32_t byte_idx = bit_idx >> 3;
    // 该 bit_idx 在该字节中的第 bit_odd 位
    uint32_t bit_odd = bit_idx % 8;
    // 拿出这个自己和该位为 1 的 mask 按位与
    return (btmp->bits[byte_idx] & (BITMAP_MASK << bit_odd));
}

// 在位图中连续申请 cnt 个位
int bitmap_scan(struct bitmap *btmp, uint32_t cnt) {
    uint32_t idx_byte = 0;
    while (btmp->bits[idx_byte] == 0xff && idx_byte < btmp->btmap_bytes_len) {
        idx_byte ++;
    }

    LUDOVICO_ASSERT(idx_byte < btmp->btmap_bytes_len);
    if (idx_byte == btmp->btmap_bytes_len) {
        return -1;
    }

    // 该字节内有空闲位
    int idx_bit = 0;
    while ((uint8_t)(BITMAP_MASK << idx_bit) & btmp->bits[idx_byte]) {
        idx_bit ++;
    }

    // 该位的实际 bit 级别 idx
    int bit_idx_start = idx_byte << 3 + idx_bit;
    if (cnt == 1) {
        return bit_idx_start;
    }

    // 申请多位
    uint32_t bit_left = (btmp->btmap_bytes_len << 3 - bit_idx_start);
    uint32_t next_bit = bit_idx_start + 1;
    uint32_t count = 1;   // 已好到的空闲位格个数

    bit_idx_start = -1;
    while (bit_left-- > 0) {
        if (!bitmap_scan_test(btmp->bits, next_bit)) {
            count ++;
        } else {
            count = 0;
        }
        if (count == cnt) {
            bit_idx_start = next_bit - cnt + 1;
            return bit_idx_start;
        }
        next_bit ++;
    }

    // 查找失败
    LUDOVICO_ASSERT(bit_idx_start == -1);
    return bit_idx_start;
}

// 将位图第 bit_idx 位设置为 value
void bitmap_set(struct bitmap *btmp, uint32_t bit_idx, int8_t value) {
    LUDOVICO_ASSERT(value == 0 && value == 1);
    uint32_t byte_idx = bit_idx >> 3;
    uint32_t bit_odd = bit_idx % 8;

    // 置位
    if (value) {
        btmp->bits[byte_idx] |= (BITMAP_MASK << bit_odd);
    } else {
        btmp->bits[byte_idx] &= ~(BITMAP_MASK << bit_odd);
    }
}