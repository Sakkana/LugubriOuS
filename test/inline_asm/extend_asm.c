#include <stdio.h>

int in_a = 1;
int in_b = 2;
int out_sum;

int main() {
    // 基本内联汇编
    asm("pusha; \
        movl in_a, %eax; \
        movl in_b, %ebx; \
        addl %ebx, %eax; \
        movl %eax, out_sum; \
        popa");
    
    printf("Through basic inline asm, sum = %d\n", out_sum);

    // 扩展内联汇编
    int local_in_a = 2;
    int local_in_b = 3;
    int local_out_sum;
    asm("addl %%ebx, %%eax":"=a"(local_out_sum):"a"(local_in_a),"b"(local_in_b));

    printf("Through extend inline asm, sum = %d\n", local_out_sum);

    return 0;
}