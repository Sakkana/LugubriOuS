	.file	"extend_asm.c"
	.text
	.section	.rodata.str1.4,"aMS",@progbits,1
	.align 4
.LC0:
	.string	"Through basic inline asm, sum = %d\n"
	.align 4
.LC1:
	.string	"Through extend inline asm, sum = %d\n"
	.section	.text.startup,"ax",@progbits
	.p2align 4
	.globl	main
	.type	main, @function
main:
.LFB23:
	.cfi_startproc
	endbr32
	leal	4(%esp), %ecx
	.cfi_def_cfa 1, 0
	andl	$-16, %esp
	pushl	-4(%ecx)
	pushl	%ebp
	movl	%esp, %ebp
	.cfi_escape 0x10,0x5,0x2,0x75,0
	pushl	%esi
	.cfi_escape 0x10,0x6,0x2,0x75,0x7c
	call	__x86.get_pc_thunk.si
	addl	$_GLOBAL_OFFSET_TABLE_, %esi
	pushl	%ebx
	pushl	%ecx
	.cfi_escape 0xf,0x3,0x75,0x74,0x6
	.cfi_escape 0x10,0x3,0x2,0x75,0x78
	subl	$16, %esp
#APP
# 9 "extend_asm.c" 1
	pusha;         movl in_a, %eax;         movl in_b, %ebx;         addl %ebx, %eax;         movl %eax, out_sum;         popa
# 0 "" 2
#NO_APP
	movl	out_sum@GOT(%esi), %eax
	movl	%esi, %ebx
	pushl	(%eax)
	leal	.LC0@GOTOFF(%esi), %eax
	pushl	%eax
	pushl	$1
	call	__printf_chk@PLT
	addl	$12, %esp
	movl	$3, %ebx
	movl	$2, %eax
#APP
# 22 "extend_asm.c" 1
	addl %ebx, %eax
# 0 "" 2
#NO_APP
	pushl	%eax
	leal	.LC1@GOTOFF(%esi), %eax
	movl	%esi, %ebx
	pushl	%eax
	pushl	$1
	call	__printf_chk@PLT
	addl	$16, %esp
	leal	-12(%ebp), %esp
	xorl	%eax, %eax
	popl	%ecx
	.cfi_restore 1
	.cfi_def_cfa 1, 0
	popl	%ebx
	.cfi_restore 3
	popl	%esi
	.cfi_restore 6
	popl	%ebp
	.cfi_restore 5
	leal	-4(%ecx), %esp
	.cfi_def_cfa 4, 4
	ret
	.cfi_endproc
.LFE23:
	.size	main, .-main
	.comm	out_sum,4,4
	.globl	in_b
	.data
	.align 4
	.type	in_b, @object
	.size	in_b, 4
in_b:
	.long	2
	.globl	in_a
	.align 4
	.type	in_a, @object
	.size	in_a, 4
in_a:
	.long	1
	.section	.text.__x86.get_pc_thunk.si,"axG",@progbits,__x86.get_pc_thunk.si,comdat
	.globl	__x86.get_pc_thunk.si
	.hidden	__x86.get_pc_thunk.si
	.type	__x86.get_pc_thunk.si, @function
__x86.get_pc_thunk.si:
.LFB24:
	.cfi_startproc
	movl	(%esp), %esi
	ret
	.cfi_endproc
.LFE24:
	.ident	"GCC: (Ubuntu 9.4.0-1ubuntu1~20.04.1) 9.4.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 4
	.long	 1f - 0f
	.long	 4f - 1f
	.long	 5
0:
	.string	 "GNU"
1:
	.align 4
	.long	 0xc0000002
	.long	 3f - 2f
2:
	.long	 0x3
3:
	.align 4
4:
