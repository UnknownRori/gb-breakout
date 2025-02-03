# Breakout game
# Gameboy color compatible

PROJECT_NAME		= breakout
BUILD_DIR			= build
SRC_DIR				= src


ROM_MAP				= $(BUILD_DIR)/$(PROJECT_NAME).map
SOURCES				= $(wildcard $(SRC_DIR)/*.asm)
OBJS 				= $(patsubst $(SRC_DIR)/%.asm, $(BUILD_DIR)/%.o, $(SOURCES))

RGBLINK_FLAG		= -m $(ROM_MAP)
RGBFIX_FLAG			= -c -j -v -p 0xFF
ROMUSAGE_FLAG		=  -sRp -g

TARGET				= $(BUILD_DIR)/$(PROJECT_NAME).gb

all: $(TARGET)

romusage: $(TARGET)
	romusage $(ROM_MAP) $(ROMUSAGE_FLAG)

$(BUILD_DIR):
	([ ! -e ./build ] && mkdir $(BUILD_DIR)) || [ -e ./build ]

$(TARGET): $(OBJS) | $(BUILD_DIR)
	rgblink $(RGBLINK_FLAG) $(OBJS) -o $(TARGET)
	rgbfix $(RGBFIX_FLAG) $(TARGET)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm | $(BUILD_DIR)
	rgbasm -o $@ $<

clean:
	rm -rf $(BUILD_DIR)
