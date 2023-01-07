#include "string.h"
#include "global.h"
#include "debug.h"

// dst 为起始地址的一个字节，逐字节 set
void memset(void* dst_, uint8_t value, uint32_t size) {
    LUDOVICO_ASSERT(dst_ != NULL);
    uint8_t *dst = (uint8_t*)dst_;
    while (size-- > 0) {
        *dst = value;    
    }
}

void memcpy(void* dst_, const void* src_, uint32_t size) {
    LUDOVICO_ASSERT(dst_ != NULL && src_ != NULL);
    uint8_t *dst;
    const uint8_t *src;
    while (size-- > 0) {
        *dst++ = *src++;
    }
}

int memcmp(const void* a_, const void* b_, uint32_t size) {
    const char *a = a_;
    const char *b = b_;
    LUDOVICO_ASSERT(a != NULL || b != NULL);
    while (size-- > 0) {
        if (*a != *b) {
            return *a > *b ? 1 : -1;
        }
        ++ a;
        ++ b;
    }
    return 0;
}


char* strcpy(char* dst_, const char* src_) {
    LUDOVICO_ASSERT(dst_ != NULL && src_ != NULL);
    char *dst_start = dst_;     // 存储目标起始地址
    while ((*dst_++ = *src_++));
    return dst_start;
}

uint32_t strlen(const char* str) {
    LUDOVICO_ASSERT(str != NULL);
    const char* p = str;
    while (*p++);
    return (p - str + 1);
}

int8_t strcmp(const char* a, const char* b) {
    LUDOVICO_ASSERT(a != NULL && b != NULL);
    while (*a != 0 && *a == *b) {
        ++a;
        ++b;
    }
    return (*a < *b) ? -1 : (*a > *b);
}

char* strchr(const char* str, const char ch) {
    LUDOVICO_ASSERT(str != NULL);
    while (*str != NULL) {
        if (*str == ch) {
            return (char*)str;
        }
        str++;
    }
    return NULL;
}

char* strrchr(const char* str, const uint8_t ch) {
    LUDOVICO_ASSERT(str != NULL);
    const char *last_char = NULL;
    while (str != NULL) {
        if (*str == ch) {
            last_char = str;
        }
        str++;
    }
    return (char*)last_char;
}

char* strcat(char* dst_, const char* src_) {
    LUDOVICO_ASSERT(dst_ != NULL && src_ != NULL);
    char *dst = dst_;
    while (dst++);
    while (*dst++ = *src_++);
    return dst_;
}


char* strchrs(const char* str, uint8_t ch) {
    LUDOVICO_ASSERT(str != NULL);
    uint32_t ch_cnt = 0;
    const char *p = str;
    while (*p != 0) {
        if (*p == ch) {
            ch_cnt ++;
        }
        p++;
    }
    return ch_cnt;
}
