# Dungeon Crawler Carl

A 2D action platformer prototype in Godot 4 (GDScript). You play Carl, with
Princess Donut riding on his shoulder, and kick your way through dungeon rooms.
No logins, database, backend, or JavaScript packages are required.

**Status: Milestone 3 (rooms and lives).** The game starts at the Floor 1
entrance. Floor 1 has 14 rooms connected as in
[docs/floor-layouts.md](docs/floor-layouts.md). The first four rooms are a
tutorial, with signs that explain the controls.

Rooms and lives:

- **Combat rooms** lock their exits until every enemy is dead. A cleared room
  stays cleared.
- **Challenge rooms** hold a trial that unlocks a reward chest: climb to it,
  kick three switches, cross pits, or defeat the guards. Opening the chest
  shows a placeholder message; the upgrade choice comes in Milestone 6.
- **Safe rooms** have no enemies and a fountain that fully heals you once per
  floor run.
- The **boss room** (F1-08) is an empty arena with no exit until Milestone 5.
- Doors only lead forward, following the arrows in the layout.
- You have **3 lives**. Dying costs one life and restarts the current room:
  its enemies come back, you return to full health, and you keep your
  potions. Progress in other rooms is kept.
- Losing the last life shows **Game Over**. Restarting the floor sends you
  back to the entrance with 3 lives, 3 potions and every room reset.
- Falling into a pit costs 20 HP and returns you to the room's entrance.

Health and healing rules:

- You start with **3 potions** and can carry at most **10**. Each potion heals
  **30 HP**, capped at your maximum. A potion isn't used up if you're at full
  health, and there's a 0.5s cooldown between drinks.
- Enemies drop a potion **20%** of the time (`potion_drop_chance`). If you
  already carry 10, a potion stays on the ground until you have room.
- **Automatic healing:** 3 seconds after combat ends, health regenerates to
  full over 10 seconds. Fighting again, taking damage or dying stops it; any
  healing already done is kept. It never runs during a boss fight.
- You're **in combat** while any enemy is chasing you (an enemy keeps chasing
  until it dies or loses you for 3 seconds) or while a room or boss encounter
  is active.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | A/D or arrows | Left stick / D-pad |
| Jump (hold for higher) | Space | South face button |
| Dodge | Left Shift | Right shoulder |
| Kick combo (tap ×3) | J | West face button |
| Power kick (hold, release) | K | North face button |
| Drink potion | H | D-pad Down |
| Interact (chest, fountain) | E | Left trigger |
| Skip to next room (debug) | N | — |

The input map already contains the later actions (switch mode, special,
pause); they do nothing yet. The N debug key goes through the room's first
exit even when it's locked. Turn it off with `debug_keys` on the Main node.

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

Alternatively, import `project.godot` directly in Godot. Press **F5** to run the
project. There are no external assets to download; all art is drawn in code.

### Project layout

```text
scenes/main/        Main.tscn — game root (player, HUD, room manager, lives flow)
scenes/player/      Player.tscn + PlayerController (movement), PlayerCombat,
                    PlayerHealth, PotionInventory, HealthRegen (auto-heal),
                    PlayerVisual (placeholder art)
scenes/enemies/     EnemyBase.gd (health/knockback/death/drops), Goblin
scenes/pickups/     PotionPickup
scenes/rooms/       RoomBase.gd (builds a room from its text map); floor1/ room scenes
scenes/environment/ SolidBlock, Door, Chest, Fountain, FloorSwitch, RoomSign
scenes/ui/          HUD, GameOver
scripts/            GameManager.gd (autoload: lives), RoomManager.gd (transitions,
                    room state), FloorData.gd (floor -> room scenes),
                    CombatStateManager.gd, Fx.gd, GameCamera.gd
scripts/abilities/  Ability base, KickCombo, ChargedKick
scripts/combat/     Hit, HitQuery (instant hitbox queries)
scripts/fx/         Placeholder effects; scripts/Fx.gd autoload (shake, hit stop)
tests/              Headless test runner
```

Tuning values (speeds, jump, dodge, damage, cooldowns, enemy stats) are
`@export` variables, so you can change them in the Inspector.

### Editing rooms

Each room scene's `layout` property is a text map of 32px tiles. The room is
built from it when the game runs, so the map won't show in the editor's 2D
view. Legend:

```text
#  solid      =  one-way platform   G  gate (opens when the trial is done)
E  entrance   1-9  exit door N      g  Goblin
C  chest      F  fountain           S  switch     i  sign     B  boss spawn
```

Signs take their text from `signs`, in reading order. Exit door N leads to
`exits[N-1]`. A full jump clears 3 tiles, so keep steps at 3 tiles or less.
Running jumps reach about 5 tiles across (4 at full height), so pits can be
up to 4 tiles wide. `make test` checks every room's map: it confirms each
exit, chest, switch and fountain can be reached from the entrance, and tests
the jump height and pit crossing with real physics.

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
make test   # Run the headless test suite (tests/TestRunner.tscn); exit code 1 on failure
make web    # Export the browser build (requires matching export templates)
make clean  # Remove generated builds
```

`make test` runs the logic and physics tests in simulated time (`--fixed-fps`),
so tests that wait out the 13 seconds of regeneration still finish in a few
seconds. The tests cover:

- **Combat:** health clamping, invulnerability, kick damage, combo timing,
  power-kick scaling, knockback direction, Goblin attacks, dead enemies not
  attacking, dodge i-frames, respawn.
- **Potions:** heal amounts, potion count, the empty/full/dead/cooldown
  checks, the 10-potion cap, drop rate, pickups, and potions left on the
  ground when you're full.
- **Combat state and healing:** combat starting and ending, the 3s wait,
  10s to full, combat stopping regeneration and the new rate afterwards,
  potions during regeneration, no healing while dead or during a boss fight,
  and potions kept after death.
- **Rooms and lives:** Floor 1 rooms and exits match the layout doc,
  transitions arrive in the right room, combat rooms lock and unlock, cleared
  rooms stay cleared, each death costs exactly one life and resets the room,
  Game Over restarts the floor, pit falls, all three trial types, the
  fountain, and the jump-height rule.

Game feel still has to be checked by hand: play through Floor 1, die a few
times, and run out of lives once.

Godot's `.godot/` cache, export credentials, and generated `build/` files are
ignored by Git. The web build also creates `build/.gdignore` so Godot does not
import its own exported files. No server-side state is stored.