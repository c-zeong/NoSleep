APP_NAME = NoSleep
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: all clean build package dmg

all: dmg

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(APP_NAME).dmg

build:
	swift build -c release --arch x86_64
	swift build -c release --arch arm64

package: build
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	# 创建通用二进制
	lipo -create \
		$(BUILD_DIR)/x86_64-apple-macosx/release/$(APP_NAME) \
		$(BUILD_DIR)/arm64-apple-macosx/release/$(APP_NAME) \
		-output $(MACOS_DIR)/$(APP_NAME)
	cp Info.plist $(CONTENTS_DIR)/
	cp Sources/Resources/icon.svg $(RESOURCES_DIR)/
	cp Sources/Resources/AppIcon.icns $(RESOURCES_DIR)/
	# 添加签名步骤
	chmod +x sign-with-cert.sh
	./sign-with-cert.sh

dmg: package
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(APP_DIR) -ov -format UDZO $(APP_NAME).dmg 