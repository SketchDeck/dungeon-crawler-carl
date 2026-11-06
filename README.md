# Dungeon Crawler Carl

A 2D action platformer prototype in Godot 4 (GDScript). You play Carl, with
Princess Donut riding on his shoulder, and kick your way through dungeon rooms.
No logins, database, backend, or JavaScript packages are required.

**Status: Milestone 5 (first boss).** Floor 1 is playable from the entrance
to the Goblin Brute. The game starts at the Floor 1
entrance. Floor 1 has 14 rooms connected as in
[docs/floor-layouts.md](docs/floor-layouts.md). The first four rooms are a
tutorial, with signs that explain the controls.

Combat modes:

- **Tab** switches between **Carl** (kicks) and **Princess Donut** (magic).
  The switch is instant and doesn't change your position, movement, health or
  potions. The same buttons do each mode's attacks.
- **Carl:** J is a 10/10/20 kick combo; hold and release K for a power kick
  (15–35 damage).
- **Donut:** J fires a magic missile (12 damage, 0.3s cooldown, about 12
  tiles of range); hold and release K for a charged blast (18–35 damage). The
  blast's size and knockback grow with the charge.
- Every ability keeps its own cooldown, and cooldowns keep running in the
  other mode. Switching can't reset them.
- Pressing Tab during an attack's wind-up queues the switch until the attack
  lands. Switching while charging or recovering drops that attack.
- Bolts already in flight keep going after a switch. Solid walls and locked
  doors stop them; one-way platforms don't. Bolts also trigger switches.
- The HUD names the active mode (orange for Carl, purple for Donut) and shows
  all five cooldowns. The other mode's slots are dimmed. A glow at Carl's feet
  shows the mode too.

Rooms and lives:

- **Combat rooms** lock their exits until every enemy is dead. A cleared room
  stays cleared.
- **Challenge rooms** hold a trial that unlocks a reward chest: climb to it,
  kick three switches, cross pits, or defeat the guards. Opening the chest
  shows a placeholder message; the upgrade choice comes in Milestone 6.
- **Safe rooms** have no enemies and a fountain that fully heals you once per
  floor run.
- The **boss room** (F1-08) holds the Goblin Brute (see below). Beating him
  opens stairs that finish the floor.
- Doors only lead forward, following the arrows in the layout.
- You have **3 lives**. Dying costs one life and restarts the current room:
  its enemies come back, you return to full health, and you keep your
  potions. Progress in other rooms is kept.
- Losing the last life shows **Game Over**. Restarting the floor sends you
  back to the entrance with 3 lives, 3 potions and every room reset.
- Falling into a pit costs 20 HP and returns you to the room's entrance.

The Goblin Brute (Floor 1 boss):

- The fight starts when you walk past the arena sign. A boss health bar
  appears at the top of the screen, and there's no automatic healing until
  he's beaten. Potions still work.
- Every attack has a warning, then a recovery window afterwards:
  - **Charge:** he crouches, a red arrow and "!!" show the direction, then he
    rushes across the arena (20 damage). Jump over him, dodge through, or
    stand on a platform. If he hits a wall he's dazed for 1.6s.
  - **Ground slam:** fists up and red stripes on the floor, then a shockwave
    runs along the ground both ways (15 damage). Jump it or stand on a
    platform.
  - **Club swing:** club pulled back and a red box shows its reach (22
    damage). Back off or dodge through.
- **Phase 2** starts at half health: he roars (immune briefly), turns red,
  and gets faster. Warnings are 25% shorter, recovery is about half as long,
  he charges faster, shockwaves travel almost twice as far, and he sometimes
  chains a second attack straight after the first.
- He has 360 HP and can't be knocked back. He's immune while roaring. He
  drops 2 potions when he dies.
- Dying in the fight costs a life and resets him to full health.
- After he's beaten, take the stairs for the **Floor Complete** screen.
  Floor 2 comes in Milestone 8, so for now you can replay Floor 1 (3 lives,
  3 potions, fresh rooms). Beating him marks Floor 1 as completed and
  unlocks Floor 2 (saved to disk in Milestone 8).

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
| Switch Carl / Donut | Tab | Left shoulder |
| Carl: kick combo (tap ×3) · Donut: magic missile | J | West face button |
| Carl: power kick · Donut: charged blast (hold, release) | K | North face button |
| Drink potion | H | D-pad Down |
| Interact (chest, fountain) | E | Left trigger |
| Skip to next room (debug) | N | — |

The input map already contains the later actions (special attack, pause);
they do nothing yet. The N debug key goes through the room's first
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
scenes/bosses/      GoblinBoss (Goblin Brute), Shockwave
scenes/pickups/     PotionPickup
scenes/rooms/       RoomBase.gd (builds a room from its text map); floor1/ room scenes
scenes/environment/ SolidBlock, Door, FloorExit (stairs), Chest, Fountain, FloorSwitch, RoomSign
scenes/ui/          HUD (incl. AbilityBar cooldowns, boss bar), GameOver, FloorComplete
scripts/            GameManager.gd (autoload: lives), RoomManager.gd (transitions,
                    room state), FloorData.gd (floor -> room scenes),
                    CombatStateManager.gd, Fx.gd, GameCamera.gd
scripts/abilities/  Ability base; Carl: KickCombo, ChargedKick; Donut: MagicMissile, ChargedBlast
scripts/combat/     Hit, HitQuery (instant hitbox queries), MagicProjectile (Donut's bolts)
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
X  stairs to the next floor (open once the boss is beaten)
```

Signs take their text from `signs`, in reading order. Exit door N leads to
`exits[N-1]`. A full jump clears 3 tiles, so keep steps at 3 tiles or less.
Running jumps reach about 5 tiles across (4 at full height), so pits can be
up to 4 tiles wide. `make test` checks every room's map: it confirms each
exit, chest, switch, fountain, enemy and one-way platform can be reached
from the entrance, and tests
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
- **Donut combat:** instant switching keeps position, health and movement;
  switches queue during a wind-up; missile and blast damage, range, facing
  and charge scaling; cooldowns survive switching; bolts keep flying after a
  switch, stop at walls, pass one-way platforms, trigger switches, and are
  removed when the room changes.
- **Goblin Brute:** immune until the fight starts; each attack's warning
  comes before its damage (swing 22, slam 15, charge 20); dodging the swing,
  jumping or standing on a platform avoids the shockwave; phase 2 at 50% with
  an immune roar, faster warnings, shorter recovery, longer shockwaves and at
  most two chained attacks; no attack three times in a row; no attacks after
  death; 2 potion drops; the boss room flow (wakes on approach, boss bar,
  encounter ends, floor unlocked, auto-heal returns 3s later); dying resets
  the boss; the stairs and Floor Complete replay.

Game feel still has to be checked by hand: play through Floor 1, die a few
times, run out of lives once, mix kicks and magic in a fight, and beat the
Goblin Brute (check that his warnings are readable and the fight feels fair).

Godot's `.godot/` cache, export credentials, and generated `build/` files are
ignored by Git. The web build also creates `build/.gdignore` so Godot does not
import its own exported files. No server-side state is stored.