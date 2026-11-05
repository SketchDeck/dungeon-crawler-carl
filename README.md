# Dungeon Crawler Carl

A room-based 2D action platformer built in Godot 4 (GDScript) for the browser. Carl kicks, Princess
Donut blasts magic, and you swap between them with one button while Donut rides on his shoulder.
Two floors built from the designer's maps, two multi-phase bosses, potions, lives, upgrades,
achievements from the Dungeon AI, and a local save file. Everything is drawn in code and synthesized
at startup, so there are no art or audio files to download.

## Prerequisites

- [Godot 4 Standard](https://godotengine.org/download/) (not .NET), version 4.3 or newer.
- Export templates for **the exact same Godot version**. In the editor, choose
  **Editor → Manage Export Templates → Download and Install**.
- Python 3 and Make for the local web workflow.

Make expects `godot` on your PATH. Override it if needed, for example
`make serve GODOT=godot4` or `make editor GODOT=/path/to/godot`.

## Start developing

```sh
make editor
```

Press **F5** to run the game. The project starts at `scenes/main/Main.tscn`, which shows the title
screen.

## Run in a browser

```sh
make serve
```

This exports a debug build into `build/web/` and serves **only that directory** at
<http://127.0.0.1:8000>. Click the game to focus it. Stop the server with **Ctrl+C**. To use another
port, run `make serve PORT=8080`.

After editing the game, run `make web` in another terminal and refresh the browser. The server does
not rebuild or live-reload automatically.

The web preset uses the Compatibility renderer and disables threads, so Python's static server works
without special cross-origin headers. Use a modern browser with WebGL 2 support. Serve exports over
HTTP rather than opening `index.html` as a local file.

### Without Make (including Windows)

Open the project in Godot and choose **Project → Export → Web → Export Project**. Export to
`build/web/index.html`, then from the repository root run:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

On Windows, use `py -3` instead of `python3`.

## Tests

```sh
make test
```

This runs a headless test scene (`tests/TestRunner.tscn`) with several hundred checks. Pure-rule
checks cover health caps and invulnerability, potion rules and drop chance, the out-of-combat
regeneration timing, and save-file sanitizing. Map checks cover the room graph: room counts per kind,
two-way links, shafts that line up, and every room reachable from the entrance. Layout checks cover
the room contents and that nothing blocks a shaft. Integration checks drive the real game through the
input map: walking floor 1's route through doors, clearing a room, opening a challenge chest, taking
the shafts, dying, and building every room on both floors. `make check` imports the project and runs a
short headless smoke run.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or arrows | Left stick / D-pad |
| Jump | Space | South (A) |
| Dodge (short dash) | Left Shift | Right shoulder |
| Basic attack (Carl kick combo / Donut magic bolt) | J | West (X) |
| Charged attack (hold, release to fire) | K | North (Y) |
| Special (Explosive Kick / Area Magic Burst) | L | East (B) |
| Switch Carl / Donut | Tab | Left shoulder |
| Use health potion | H | D-pad down |
| Interact (chests, bonfires) | E | Left trigger |
| Pause | Esc | Start |

Bindings are defined in `scripts/autoload/controls.gd`.

## Floors and rooms

The floors come from the designer's maps, encoded in [floor_maps.gd](scripts/rooms/floor_maps.gd):

- **Floor 1 (The Warrens)** has 14 rooms. The first four form the tutorial, and their signs teach
  movement, kicks, bonfires, and Donut's magic.
- **Floor 2 (The Mutant Pool)** has 15 rooms, with Slimes and the Mutating Slime boss.

Room kinds follow the map colours:

| Kind | Colour | What it is |
| --- | --- | --- |
| Entrance | Blue | Where the floor starts. No enemies. |
| Combat | Yellow | Enemies wake when you enter. Clear them to unlock the exits. |
| Safe | Green | No enemies. A bonfire restores health (E). |
| Challenge | Purple | A fight with hazards. Clearing it unlocks the upgrade chest. This is the treasure room. |
| Boss | Red | The floor's boss. Beating it completes the floor. |

Exits go left and right through wall doors, and up and down through shafts. An up shaft has stone
one-way ledges you jump up through (hold Space to climb to full height), and a ceiling opening; a down shaft is a hole in the floor. Walking into a shaft takes you to
the room it connects to. Doors work both ways, so you can backtrack, and every room on a floor is
reachable from its entrance. Exits lock while an encounter is active.

[room_data.gd](scripts/rooms/room_data.gd) builds each room from the map: walls, shafts, stairs, and
spawn points. The room contents (platforms, enemies, hazards, signs) are in
[layout_floor1.gd](scripts/rooms/layout_floor1.gd) and [layout_floor2.gd](scripts/rooms/layout_floor2.gd).

## How it is organized

| Path | What lives there |
| --- | --- |
| `scripts/core/config.gd` | Every balance number: movement, damage, cooldowns, drop chance, regen, bosses, upgrades. Tune here. |
| `scripts/core/` | Pure logic with no nodes: `health_state`, `potion_inventory`, `regen_controller`, hitboxes, explosions. |
| `scripts/autoload/` | Global systems: `Game` (run state), `Save` (JSON save file), `CombatState` (combat and regen), `DungeonAI` (achievements), `Fx`, `Sfx`, `Controls`. |
| `scripts/player/` | Carl and Donut: `player.gd` (body and rules), `player_controller.gd` (movement), `player_combat.gd` (input routing), `abilities/` (one script per ability), `player_visual.gd`. |
| `scripts/enemies/`, `scripts/bosses/` | Goblin, Slime, Goblin Brute, Mutating Slime, plus shared `enemy_base.gd` and `boss_base.gd`. |
| `scripts/environment/` | Spikes, explosive barrels, breakable crates, potion pickups, treasure chests, bonfires, puddles, tutorial signs. |
| `scripts/rooms/` | The map: `floor_maps.gd`. Room contents: `layout_floor1.gd`, `layout_floor2.gd`. Building rooms: `room_data.gd`, `room_base.gd`. Art: `room_backdrop.gd`, `decor.gd`. |
| `scripts/ui/` | Title menu, settings, pause and other panels, and the HUD. |
| `scripts/main/main.gd` | The root: title screen, world lifecycle, room transitions, death and respawn, game over, floor completion. |
| `scenes/` | Scene files. Rooms are instances of `scenes/rooms/RoomBase.tscn`, filled from the map and layouts. |
| `tests/` | Headless tests (`test_runner.gd`) and a windowed screenshot tour (`screenshot_tour.gd`). |

## Game rules

- **Combat modes.** Carl (warm orange) kicks: a three-hit combo (10, 10, then 20 damage with stronger
  knockback), and a charged power kick (15 to 35 damage). Donut (purple) fires a 12-damage magic bolt
  and a charged blast (18 to 35 damage). Switching is instant, costs nothing, and does not move the
  player or reset cooldowns. If you switch during a non-interruptible attack, the switch waits until
  the attack finishes.
- **Health and potions.** 100 HP shared by Carl and Donut, with 0.75 s of invulnerability after a hit.
  Potions heal 30 HP, carry up to 10, and cost one per use. Using one at full health does nothing and
  costs nothing. Enemies drop potions 20% of the time (`POTION_DROP_CHANCE`). Boss drops stay on the
  ground until the fight ends.
- **Regeneration.** Healing starts 3 seconds after combat ends. It fills the missing health over 10
  seconds (so the rate depends on how much is missing), and it never uses potions. Entering combat
  cancels it immediately, and it never runs during a boss fight.
- **Lives and floors.** Three lives. Losing one restarts the current room with full health, keeping
  potions and upgrades. Losing all three restarts the floor with three lives and three potions, and it
  clears temporary upgrades. Beating a boss unlocks the next floor and grants that floor's ability
  permanently: Explosive Kick after Floor 1, Area Magic Burst after Floor 2.
- **Upgrades.** Clearing a challenge room unlocks its chest. Open it to pick one of three temporary
  upgrades, which last until the floor ends.
- **Dungeon AI.** Three achievements, each announced once per encounter. Kick an enemy into another
  enemy for more knockback in the next three rooms. Kill an enemy with a hazard for more damage in the
  next two rooms. Clear a combat room without taking damage for 15 HP.
- **Save file.** Progress and settings are stored in Godot's `user://save_game.json`. Only floors,
  unlocks, and settings are saved, never the state of an active room. A missing or corrupt file falls
  back to defaults.

## Debug keys (debug builds only)

- **F1**: unlock both special abilities and mark both floors complete.
- **F2**: warp to the next room along the floor's route to the boss.
- **F3**: warp to the floor's boss room.

## Known gaps and notes

- **Room layouts.** The room graph, room kinds, and links come straight from the maps. The geometry
  inside each room (platforms, enemy positions, hazards) is still placeholder, following the spec's
  rule to use placeholder geometry where details are missing. Replace the platforms and hazards in
  the layout files when real room art and layouts are ready. The shafts, stairs, and doors are
  generated, so they keep working as long as the room contents respect the shaft rules the tests check.
- **Interpretations to confirm.** The maps don't say what the purple rooms do; I treated them as the
  spec's treasure rooms, with the upgrade chest unlocked by clearing the fight. The arrows are treated
  as layout, not one-way travel, so doors work both ways. Shafts are placed at x = 400 and x = 880.
- **Input remapping** is not implemented. The spec lists it as "if feasible". Bindings are in one file,
  so adding a remap screen later is straightforward.
- **Quit** is hidden in the browser, where quitting does nothing.
- **Sound** is synthesized in code (`scripts/autoload/sfx.gd`). It is basic on purpose, so it can be
  swapped for real audio files later without touching gameplay code.
