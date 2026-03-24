APP_NAME := Sati
BUILD_DIR := build/DerivedData
APP_PATH := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app
INSTALL_DIR := /Applications
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: build install uninstall clean

build:
	@echo "Building $(APP_NAME)..."
	@xcodebuild -project Sati/Sati.xcodeproj \
		-scheme Sati \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS' \
		ENABLE_APP_SANDBOX=NO \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_ALLOWED=YES \
		2>&1 | tail -20
	@$(LSREGISTER) -f "$(APP_PATH)"
	@echo "Done!"

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -R "$(APP_PATH)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@$(LSREGISTER) -f "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed."

uninstall:
	@echo "Removing $(APP_NAME) from $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed."

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Clean."
