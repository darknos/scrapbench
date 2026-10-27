APP      = Scrapbench
BUILD    = build
BUNDLE   = $(BUILD)/$(APP).app
BIN      = $(shell swift build -c release --show-bin-path)
# Signing identity: "-" is ad-hoc; pass SIGN="Developer ID Application: ..." for a real one.
SIGN    ?= -

.PHONY: build app run test clean sample

build:
	swift build -c release --product ScrapbenchApp

test:
	swift test

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BIN)/ScrapbenchApp $(BUNDLE)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	# KeyboardShortcuts ships a resource bundle for its recorder UI
	-cp -R $(BIN)/KeyboardShortcuts_KeyboardShortcuts.bundle $(BUNDLE)/Contents/Resources/ 2>/dev/null
	codesign --force --sign "$(SIGN)" --deep --options runtime --timestamp=none $(BUNDLE)
	@echo "built $(BUNDLE)"

run: app
	open $(BUNDLE)

sample:
	Scripts/make-sample.sh $(BUILD)/sample-scraps.md

clean:
	rm -rf $(BUILD) .build
