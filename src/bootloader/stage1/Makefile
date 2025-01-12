BUILD_DIR?=build
ASM?=nasm
CC16?=/usr/bin/watcom/binl64/wcc
LD16?=/usr/bin/watcom/binl64/wlink

.PHONY: all stage1 clean

all: stage1

stage1: $(BUILD_DIR)/stage1.bin

$(BUILD_DIR)/stage1.bin:
	$(ASM) boot.asm -f bin -o $(BUILD_DIR)/stage1.bin

clean:
	rm -f $(BUILD_DIR)/stage1.bin

#
# Always
#
always:
	mkdir -p $(BUILD_DIR)
