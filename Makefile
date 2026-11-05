GODOT ?= godot
PYTHON ?= python3
PORT ?= 8000

.PHONY: editor check web serve clean

editor:
	$(GODOT) --editor --path .

check:
	$(GODOT) --headless --path . --editor --import
	$(GODOT) --headless --path . --quit-after 2

web:
	mkdir -p build/web
	touch build/.gdignore
	$(GODOT) --headless --path . --export-debug Web build/web/index.html

serve: web
	$(PYTHON) -m http.server $(PORT) --bind 127.0.0.1 --directory build/web

clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
