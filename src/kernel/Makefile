BUILD_DIR?=build
ASM?=nasm
CC16?=/usr/bin/watcom/binl64/wcc
LD16?=/usr/bin/watcom/binl64/wlinkasm

.PHONY: all kernel clean

all: kernel

kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin:
	$(ASM) main.asm -f bin -o $(BUILD_DIR)/kernel.bin

clean:
	rm -f $(BUILD_DIR)/kernel.bin

#
# Always
#
always:
	mkdir -p $(BUILD_DIR)
