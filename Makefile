GODOT ?= godot
PYTHON ?= python3
PORT ?= 8000
## itch.io upload target for `make itch`, e.g. ITCH_TARGET=yourname/dungeon-crawler-carl
ITCH_TARGET ?=

.PHONY: editor check test web serve clean audio playtest itch

editor:
	$(GODOT) --editor --path .

check:
	$(GODOT) --headless --path . --editor --import
	$(GODOT) --headless --path . --quit-after 2

test:
	$(GODOT) --headless --path . --import
	$(GODOT) --headless --path . --fixed-fps 60 tests/TestRunner.tscn

audio:
	$(PYTHON) tools/gen_audio.py

web:
	mkdir -p build/web
	touch build/.gdignore
	$(GODOT) --headless --path . --export-debug Web build/web/index.html

## Release build for the team (debug keys off) plus a zip ready for itch.io.
playtest:
	rm -rf build/playtest
	mkdir -p build/playtest
	touch build/.gdignore
	$(GODOT) --headless --path . --export-release "Web Playtest" build/playtest/index.html
	$(PYTHON) tools/zip_build.py build/playtest build/dcc-playtest.zip

## Uploads the playtest build to itch.io with butler (see docs/playtesting.md).
itch: playtest
	@command -v butler >/dev/null || { echo "butler isn't installed: see docs/playtesting.md"; exit 1; }
	@test -n "$(ITCH_TARGET)" || { echo "Set ITCH_TARGET, e.g. make itch ITCH_TARGET=yourname/dungeon-crawler-carl"; exit 1; }
	butler push build/playtest $(ITCH_TARGET):html5

serve: web
	$(PYTHON) -m http.server $(PORT) --bind 127.0.0.1 --directory build/web

clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
