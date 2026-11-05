# Dungeon Crawler Carl

A minimal Godot 4 web game. No logins, database, backend, or JavaScript packages
are required. The starter scene draws a room and a player you can move with WASD
or the arrow keys.

## Prerequisites

- [Godot 4 Standard](https://godotengine.org/download/) (not .NET), version 4.3
  or newer; use the current stable release.
- Export templates for **the exact same Godot version**. In the editor, choose
  **Editor → Manage Export Templates → Download and Install**.
- Python 3 and Make for the local web workflow.

Make expects `godot` on your PATH. Override it if needed, for example
`make serve GODOT=godot4` or `make editor GODOT=/path/to/godot`.

## Start developing

```sh
make editor
```

Alternatively, import `project.godot` directly in Godot. Press **F6** to run the
current scene or **F5** to run the project. Start building in `scenes/main.tscn`
and `scripts/main.gd`; there are no external assets to download.

## Run in a browser

```sh
make serve
```

This exports a debug build into `build/web/` and serves **only that directory** at
<http://127.0.0.1:8000>. Click the game to focus it, then use WASD or the arrow
keys. Stop the server with **Ctrl+C**. To use another port:

```sh
make serve PORT=8080
```

After editing the game, run `make web` in another terminal and refresh the browser.
The server does not rebuild or live-reload automatically.

The web preset uses the Compatibility renderer and disables threads, so Python's
static server works without special cross-origin isolation headers. Use a modern
browser with WebGL 2 support. Serve exports over HTTP rather than opening
`index.html` as a local file.

### Without Make (including Windows)

Open the project in Godot and choose **Project → Export → Web → Export Project**.
Create `build/web/` if necessary and export to `build/web/index.html`. From the
repository root, run:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

On Windows, use `py -3` instead of `python3`.

## Validation and build commands

```sh
make check  # Import/parse project resources, then run a short headless smoke check
make web    # Export the browser build (requires matching export templates)
make clean  # Remove generated builds
```

There is no automated gameplay test suite yet. To smoke-test a change, run
`make check`, export with `make web`, and open the locally served game. Check
movement in all directions and verify the player stays inside the room.

Godot's `.godot/` cache, export credentials, and generated `build/` files are
ignored by Git. No server-side state is stored.