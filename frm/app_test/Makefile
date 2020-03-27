#***********************************************************************************************
#    File        : Makefile
#    Author      : Lyu Yang
#    Date        :
#    Description : Makefile for RISC-V
#***********************************************************************************************

TARGET = app_test

CROSS_COMPILE = riscv64-unknown-elf-

INCLUDE_DIRS = -I ./
LIBRARY_DIRS = -L ./

CC = $(CROSS_COMPILE)gcc
CFLAGS =  $(INCLUDE_DIRS) -c -mabi=ilp32 -march=rv32i -Wall -O1 -std=c99 -gdwarf-2 -freorder-blocks-algorithm=simple -fno-schedule-insns -fno-aggressive-loop-optimizations -fno-builtin -Wstrict-prototypes -Wno-write-strings -fno-exceptions -fno-short-enums -Wundef -falign-functions=2 -fdata-sections -ffunction-sections -fno-common

CXX = $(CROSS_COMPILE)g++
CXXFLAGS =  $(INCLUDE_DIRS) -c -mabi=ilp32 -march=rv32i -Wall -O1 -std=c99 -gdwarf-2 -freorder-blocks-algorithm=simple -fno-schedule-insns -fno-aggressive-loop-optimizations -fno-builtin -Wstrict-prototypes -Wno-write-strings -fno-exceptions -fno-short-enums -Wundef -falign-functions=2 -fdata-sections -ffunction-sections -fno-common

AS = $(CROSS_COMPILE)gcc
ASFLAGS = -c -mabi=ilp32 -march=rv32i -x assembler-with-cpp -Wall -O1 -gdwarf-2 -fstack-protector -fno-common -fdata-sections -ffunction-sections

LD = $(CROSS_COMPILE)gcc
LDFLAGS = $(LIBRARY_DIRS) -mabi=ilp32 -march=rv32i -nostartfiles -Triscv.lds -Wl,-Map,$(TARGET).map

OBJCP = $(CROSS_COMPILE)objcopy
OBJCPFLAGS = -O binary -j .text -j .data -j .sdata

AR = $(CROSS_COMPILE)ar
ARFLAGS = cr

DUMP = $(CROSS_COMPILE)objdump
DUMPFLAG = --disassemble --syms --all-header

SIZE = $(CROSS_COMPILE)size

OBJS += $(patsubst %.S, %.o, $(wildcard *.S))
OBJS += $(patsubst %.c, %.o, $(wildcard *.c))
DEPS += $(OBJS:%.o=%.d)

# Make
all: $(TARGET).elf $(TARGET).bin $(TARGET).asm $(TARGET).mif
	$(SIZE) $(TARGET).elf

%.o: %.S
	@$(AS) $(ASFLAGS) $^ -o $@
	@echo AS $^ -o $@

%.o: %.c
	@$(CC) $(CFLAGS) -MM -MT $@ -MF $(patsubst %.o, %.d, $@) $<
	@$(CC) $(CFLAGS) -o $@ $<
	@echo CC $^ -o $@

$(TARGET).elf: $(OBJS)
	@$(LD) $(LDFLAGS) $^ -o $@

$(TARGET).asm: $(TARGET).elf
	@$(DUMP) $(DUMPFLAG) $(TARGET).elf > $(TARGET).asm

$(TARGET).bin: $(TARGET).elf
	@$(OBJCP) $(OBJCPFLAGS) $< $@

$(TARGET).mif: $(TARGET).bin
	@./bin2fpga/bin2fpga 4096 $< > $(TARGET).txt

clean:
	@rm -rf $(OBJS) $(DEPS) $(TARGET).elf $(TARGET).map $(TARGET).asm $(TARGET).bin $(TARGET).txt

debug:
	$(CROSS_COMPILE)gdb $(TARGET).elf -x gdbinit.txt

