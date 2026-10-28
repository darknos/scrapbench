APP      = Scrapbench
BUILD    = build
BUNDLE   = $(BUILD)/$(APP).app
BIN      = $(shell swift build -c release --show-bin-path)
# Signing identity: "-" is ad-hoc; pass SIGN="Developer ID Application: ..." for a real one.
# A real identity gets a secure timestamp, which notarization requires; ad-hoc cannot have one.
SIGN    ?= -
TIMESTAMP = $(if $(filter -,$(SIGN)),--timestamp=none,--timestamp)

ICONS    = $(BUILD)/icons/AppIcon.icns

.PHONY: build app run test clean sample icons

build:
	swift build -c release --product ScrapbenchApp

test:
	swift test

icons: $(ICONS)

$(ICONS): Resources/Icon/AppIcon.svg Resources/Icon/MenuIcon.svg Scripts/make-icons.sh
	mkdir -p $(BUILD)/icons
	Scripts/make-icons.sh $(BUILD)/icons

app: build $(ICONS)
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BIN)/ScrapbenchApp $(BUNDLE)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp $(BUILD)/icons/AppIcon.icns $(BUILD)/icons/MenuIcon.png $(BUILD)/icons/MenuIcon@2x.png $(BUNDLE)/Contents/Resources/
	# KeyboardShortcuts ships a resource bundle for its recorder UI
	-cp -R $(BIN)/KeyboardShortcuts_KeyboardShortcuts.bundle $(BUNDLE)/Contents/Resources/ 2>/dev/null
	codesign --force --sign "$(SIGN)" --deep --options runtime $(TIMESTAMP) $(BUNDLE)
	@echo "built $(BUNDLE)"

run: app
	open $(BUNDLE)

sample:
	Scripts/make-sample.sh $(BUILD)/sample-scraps.md

clean:
	rm -rf $(BUILD) .build
