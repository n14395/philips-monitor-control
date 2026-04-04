APP_NAME = PhilipsMultiView
BUNDLE = $(APP_NAME).app
BUILD_DIR = .build/release

.PHONY: build bundle clean run

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/

run: bundle
	open $(BUNDLE)

clean:
	swift package clean
	rm -rf $(BUNDLE)
