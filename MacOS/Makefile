APP_NAME = PhilipsMultiView
BUNDLE = $(APP_NAME).app
BUILD_DIR = .build/release

.PHONY: build bundle clean run

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	@SVG=../assets/com.n14395.monitorcontrol.svg; \
	if [ -f "$$SVG" ] && command -v rsvg-convert >/dev/null 2>&1; then \
		echo "Generating AppIcon.icns..."; \
		ICONSET=$$(mktemp -d)/AppIcon.iconset; \
		mkdir -p "$$ICONSET"; \
		for SIZE in 16 32 128 256 512; do \
			rsvg-convert -w $$SIZE -h $$SIZE "$$SVG" -o "$$ICONSET/icon_$${SIZE}x$${SIZE}.png"; \
			DOUBLE=$$((SIZE * 2)); \
			rsvg-convert -w $$DOUBLE -h $$DOUBLE "$$SVG" -o "$$ICONSET/icon_$${SIZE}x$${SIZE}@2x.png"; \
		done; \
		iconutil -c icns -o $(BUNDLE)/Contents/Resources/AppIcon.icns "$$ICONSET"; \
		rm -rf "$$(dirname "$$ICONSET")"; \
	else \
		echo "(skipping icon — install librsvg for .icns generation)"; \
	fi

run: bundle
	open $(BUNDLE)

clean:
	swift package clean
	rm -rf $(BUNDLE)
