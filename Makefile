# *************************************************************
# * *************** Copyright@github.com/Sakkana **************
# * ***************** Author:Sakana ***************************
# * ****************** Date:${2022.12.10} *********************
# * ***Description: A Makefile for my tiny operating system ***
# * ************ written in 80x86 assembly and C **************
# * ************ OS:				Windows 10 ****************
# * ************ Assembler: 		NASM version 2.08 *********
# * ************ Compiler:  		MinGW gcc version 9.2.0 ***
# * ************ Virtual Machine: 	Bochs x86 Emulator 2.4.5 **
# *************************************************************

NASM = nasm
NASM_HEADER = -I
RM = del
DD = dd
BOCHSRUN = bochsdbg.exe

MBR = bin\\mbr.bin
LOADER = bin\\loader.bin
TARGET = img\\myOS.img
CONFIG = config\\myOS.bxrc
INCLUDE = src\\boot\\include\\
BUILD = bin\*.bin
BLOCKSIZE = bs

os: clean build_asm write_disk run

build_asm:
	$(NASM) $(NASM_HEADER) $(INCLUDE) -o $(MBR) src\\boot\\mbr.asm
	$(NASM) $(NASM_HEADER) $(INCLUDE) -o $(LOADER) src\\boot\\loader.asm
	
# |-fin0- |-fin1-|-fin2-|-fin3-|
# |  MBR  |      |   Loader    |	
# |0x7c00 |		 |    0x900    |	

write_disk:
	DD if=$(MBR) of=$(TARGET) $(BLOCKSIZE)=512 count=1 conv=notrunc
	DD if=$(LOADER) of=$(TARGET) $(BLOCKSIZE)=512 count=3 seek=2 conv=notrunc
	
run:
	$(BOCHSRUN) -f $(CONFIG) -q

.PHONY : clean
clean:
	$(RM) $(BUILD)