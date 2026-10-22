ASM := nasm

QEMU := qemu-system-i386

SRC := src
BUILD := build

TARGET := $(BUILD)/lunarix.img

$(TARGET): $(BUILD)/main.bin
	cp $(BUILD)/main.bin $(TARGET)
	truncate -s 1440k $(TARGET)

$(BUILD)/main.bin: $(SRC)/main.asm
	mkdir $(BUILD)
	$(ASM) $(SRC)/main.asm -f bin -o $(BUILD)/main.bin

run: $(TARGET)
	qemu-system-i386 -fda $(TARGET)

clean:
	rm -rvf $(BUILD)
