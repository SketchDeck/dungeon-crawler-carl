GODOT ?= godot
PYTHON ?= python3
PORT ?= 8000

.PHONY: editor check test web serve clean

editor:
	$(GODOT) --editor --path .

check:
	$(GODOT) --headless --path . --editor --import
	$(GODOT) --headless --path . --quit-after 2

test:
	$(GODOT) --headless --path . --import
	$(GODOT) --headless --path . --fixed-fps 60 tests/TestRunner.tscn

web:
	mkdir -p build/web
	touch build/.gdignore
	$(GODOT) --headless --path . --export-debug Web build/web/index.html

serve: web
	$(PYTHON) -m http.server $(PORT) --bind 127.0.0.1 --directory build/web

clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
