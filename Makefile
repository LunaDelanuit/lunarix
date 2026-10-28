ASM := nasm

QEMU := qemu-system-i386

SRC := src
BUILD := build

BOOTS := $(SRC)/boot
KERNELS := $(SRC)/kernel

BOOTB := $(BUILD)/boot.bin
KERNELB := $(BUILD)/kernel.bin
TARGET := $(BUILD)/lunarix.img

.PHONY: all $(TARGET) floppy boot kernel

floppy: $(TARGET)

$(TARGET): boot kernel
	dd if=/dev/zero of=$(TARGET) bs=512 count=2880
	mkfs.fat -F 12 -n "LUNARIX" $(TARGET)
	dd if=$(BOOTB) of=$(TARGET) conv=notrunc
	mcopy -i $(TARGET) $(KERNELB) "::kernel.bin"

boot: $(BUILD)/boot.bin

$(BUILD)/boot.bin: always
	$(ASM) $(BOOTS)/boot.asm -f bin -o $(BOOTB)

kernel: $(BUILD)/kernel.bin

$(BUILD)/kernel.bin: always
	$(ASM) $(KERNELS)/main.asm -f bin -o $(KERNELB)

always:
	mkdir -p $(BUILD)

run: $(TARGET)
	qemu-system-i386 -fda $(TARGET)

debug: $(TARGET)
	bochs -f bochs_config -q

clean:
	rm -rvf $(BUILD)
