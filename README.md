# Dungeon Crawler Carl

A 2D action platformer prototype in Godot 4 (GDScript). You play Carl, with
Princess Donut riding on his shoulder, and kick your way through dungeon rooms.
No logins, database, backend, or JavaScript packages are required.

**Status: all 8 milestones done (first playable prototype).** Both floors
are playable end to end: Floor 1 (14 rooms, the Goblin Brute) and Floor 2 (15
rooms, Slimes, the Mutating Slime), with special abilities, treasure
upgrades, hazards, Dungeon AI achievements, menus, settings, saves, sound,
music and controller support. The game opens on the main menu.
Rooms are connected as in
[docs/floor-layouts.md](docs/floor-layouts.md). The first four rooms are a
tutorial, with signs that explain the controls. Doors that lead to different
paths are labelled (HIGH/LOW, UPPER/MIDDLE/LOWER).

Menus and saves:

- **Main menu:** **Continue** (once you've started a game) starts your latest
  unlocked floor; once Floor 2 is unlocked you can also pick **Play Floor 1**
  or **Play Floor 2**. **New Game** asks before erasing your progress (your
  settings are kept). **Settings**, and **Quit** (hidden in the browser).
- Starting a floor from the menu is a fresh run: 3 lives, 3 potions, no
  upgrades. Going straight from Floor 1's Floor Complete screen to Floor 2
  keeps your potions instead.
- **Pause** with Esc (Start on a controller): Resume, Settings, Main Menu.
  It won't open over Game Over, Floor Complete or the treasure screen.
- **Game Over** and **Floor Complete** also have a Main Menu button.
- **Settings:** master, music and sound-effect volume, fullscreen, and
  keyboard remapping for every gameplay action (click an action's key, then
  press the new key; Esc cancels; **Reset keys** restores the defaults).
  Controller buttons aren't remappable, and Esc always pauses. The controls
  hint at the bottom of the HUD follows your bindings.
- Everything is saved to `user://save.json`: whether you've started a game,
  completed floors, the unlocked floor, ability unlocks and settings. Never a
  room in progress, so Continue always starts at a floor's entrance. Losing
  on Floor 2 doesn't undo Floor 1. A missing or broken save just starts
  fresh.

Sound and music:

- Placeholder sound effects for attacks, hits, deaths, potions, hazards,
  boss warnings, achievements and menus, plus looping music: a menu theme,
  one track per floor and a boss theme (it starts when a boss wakes and
  hands back to the floor music when the boss dies). Game Over stops the
  music.
- Volumes are in Settings (master, music, sound effects).
- In the browser, sound starts after you click the game (browsers block
  audio until you interact with the page).
- Every sound is synthesized by `tools/gen_audio.py` into `assets/sounds/`
  and `assets/music/` (music is Ogg Vorbis, so `make audio` needs
  `oggenc`: `brew install vorbis-tools`). Edit a recipe there and run
  `make audio` to regenerate.

Controller:

- Every action has a controller button (see Controls), and menus work with
  the D-pad/stick, A to confirm and B to go back.
- Prompts follow the device you last touched: the HUD hints, ability slots
  and "[LT] Open chest" style prompts switch between keyboard keys and
  controller buttons automatically, and so do tutorial signs.

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
  every cooldown. The other mode's slots are dimmed. A glow at Carl's feet
  shows the mode too.

Special abilities (L, depends on the mode):

- **Explosive Kick (Carl):** tap or hold L, then release. It hits like a power
  kick (15–35), then explodes at Carl's foot: 20 damage to everything nearby,
  pushes it away from the blast, and sets off barrels. 3.5s cooldown.
  **Unlocked by beating Floor 1.**
- **Area Magic Burst (Donut):** press L. A purple ring shows the radius while
  Donut casts, then a shockwave deals 22 damage all around you and pushes
  enemies away. 6s cooldown. **Unlocked by beating Floor 2.**
- Locked specials show LOCKED on the HUD. For testing, press **U** to unlock
  both (debug key).
- Unlocks are permanent and saved in `user://save.json`, together with which
  floors you've completed. A missing or broken save file just starts fresh.

Treasure and temporary upgrades:

- Opening a challenge room's chest pauses the game and offers **three random
  upgrades** (name and effect). Pick one with the mouse, keyboard or
  controller.
- The six upgrades are Steel-Toed Boots (+25% kick damage), Tiara Polish
  (+25% magic damage), Extra Oomph (+30% knockback), Quick Reflexes (−20%
  cooldowns), Hearty Snack (+20 max HP) and Fresh Socks (+12% move speed).
  Their strengths live in `resources/upgrades/*.tres`. Upgrades stack;
  cooldowns never drop below 40%.
- Upgrades last for the current floor: you keep them when you lose a life,
  and lose them when the floor restarts (Game Over or Replay) or is completed.
  The HUD lists the ones you have.

Environmental combat:

- **Spikes** (in shallow pits) hurt anything that touches them: 15 to you
  (you bounce out), 30 to enemies. Kick goblins in to finish them off.
  Goblins won't walk in on their own.
- **Explosive barrels** blow up shortly after any attack hits them: 30 damage
  to enemies and 20 to you within the blast, with knockback. Blasts set off
  other barrels.
- **Crates and cracked walls** only break under strong hits: the third kick
  of a combo, a power kick, a charged blast (half charge or more),
  explosions and the Magic Burst. Crates hold a potion; the cracked wall in
  Crossroads Rest (F1-06) hides one.
- **Enemy collisions:** an enemy knocked back hard (third kick, power kick,
  big blasts) that slams into another enemy deals 15 to it and takes 8
  itself, once per pair per knockback.
- None of this is required to clear a room.

Dungeon AI achievements:

- The Dungeon AI announces showy plays in a panel at the top right. It never
  pauses the game, and several announcements queue up.
- **Kick an enemy into another enemy:** +50% knockback for this room and the
  next three.
- **Kill an enemy with spikes or a barrel:** +25% damage (kicks and magic)
  for this room and the next three.
- **Clear a combat room without taking any damage (Untouchable):** +25 HP
  straight away.
- Each achievement triggers at most once per room encounter. Restarting a
  room after dying starts a new encounter. Earning a boost again refreshes it
  to three rooms rather than stacking.
- Active boosts and their rooms left show under the HUD's upgrades line.
  Boosts survive losing a life (a restarted room doesn't count as a new room)
  and end when the floor restarts or is completed.

Rooms and lives:

- **Combat rooms** lock their exits until every enemy is dead. A cleared room
  stays cleared.
- **Challenge rooms** hold a trial that unlocks a reward chest: climb to it,
  kick three switches, cross pits, or defeat the guards. Opening the chest
  lets you choose an upgrade (see below).
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
- After he's beaten, take the stairs for the **Floor Complete** screen and
  **Continue to Floor 2**: full health, lives back to 3, unused potions come
  with you, Floor 1's upgrades and boosts end. Beating him marks Floor 1 as
  completed, unlocks Floor 2 and the Explosive Kick, and saves that progress.
  (You can also replay Floor 1 from the start.)

Floor 2 enemies:

- **Slimes** sit still, squash down and flash (with a "!") and then hop at
  you. They only hurt while they're in the air (10 damage), so you can stand
  next to a resting slime safely. They won't hop off ledges or into spike
  pits on their own, but you can kick them in.

Enemies that want a particular mode (Milestone 9):

- An icon over these enemies shows their weakness: an orange **boot** means
  kicks, a purple **star** means magic. It grows when you hit them the wrong
  way, along with a "clank" and a BLOCKED message.
- **Shield Goblin** (Floor 1): kicks from the front clank off its shield.
  Magic gets through, and so do kicks from behind (jump over it) and
  explosions. 60 HP.
- **Cave Bat** (both floors): hovers above you, out of reach of a standing
  kick, flashes red, then dives at where you were standing (10 damage). Donut's
  bolts curve up or down toward flying enemies, so magic is the easy answer;
  a jump kick also works. 20 HP.
- **Armored Slime** (Floor 2): magic splashes off its shell and light kicks do
  half damage. A heavy kick (combo finisher, power kick) or an explosion
  cracks the shell, and then magic does 1.5× damage.
- **Juggling:** a heavy kick (combo finisher or power kick) launches an
  enemy. Magic that hits it before it lands does **double damage** and
  earns the Juggler achievement.

The Mutating Slime (Floor 2 boss):

- Same rules as the Brute: wakes when you walk in, boss bar, no auto-heal,
  immune while transforming, 2 guaranteed potions, resets if you die.
- **Glob volley:** it swells while dotted arcs show where each glob will
  land (red marks on the floor), then lobs 5 globs (12 damage each). The arcs
  are fixed, so stand in a gap between marks.
- **Jump slam:** it crouches while a red marker shows where it will land
  (where you were standing), then leaps there (20 damage if it lands on you)
  and leaves an acid pool (8 damage while you stand in it). Move away.
- **Phase 2** (half health): it turns purple, warnings get 25% shorter and
  recovery shorter, it lobs 7 globs that each leave a small acid pool,
  landing pools get bigger and last longer, and it splits off pairs of
  **mini slimes**. The minis and all acid vanish when it dies.
- It has 420 HP. Beating it completes Floor 2, permanently unlocks the Magic
  Burst, and ends the run (Floor Complete lets you replay Floor 2).

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
| Special: Explosive Kick · Magic Burst (once unlocked) | L | East face button |
| Drink potion | H | D-pad Down |
| Interact (chest, fountain) | E | Left trigger |
| Pause | Esc | Start |
| Skip to next room (debug) | N | — |
| Unlock both specials (debug) | U | — |

Keyboard keys can be changed in Settings. Menus work with the mouse, the
arrow keys + Enter/Esc, or the D-pad/stick + A/B (B also closes the pause
menu). The N debug key goes through
the room's first exit even when it's locked. Turn off both debug keys with
`debug_keys` on the Main node.

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
project. There are no external assets to download: all art is drawn in code,
and the sounds in `assets/` are generated by `tools/gen_audio.py`.

### Project layout

```text
scenes/main/        Main.tscn — game root (player, HUD, room manager, lives flow)
scenes/player/      Player.tscn + PlayerController (movement), PlayerCombat,
                    PlayerHealth, PotionInventory, HealthRegen (auto-heal),
                    PlayerUpgrades (temporary upgrades), PlayerVisual (placeholder art)
scenes/enemies/     EnemyBase.gd (health/knockback/death/drops), Goblin, Slime, MiniSlime
scenes/bosses/      BossBase.gd (shared boss rules), GoblinBoss (Goblin Brute), Shockwave,
                    SlimeBoss (Mutating Slime), SlimeGlob, AcidPool
scenes/pickups/     PotionPickup
scenes/rooms/       RoomBase.gd (builds a room from its text map); floor1/, floor2/ room scenes
scenes/environment/ SolidBlock, Door, FloorExit (stairs), Chest, Fountain, FloorSwitch, RoomSign,
                    SpikeTrap, ExplosiveBarrel, Breakable (crates, cracked walls)
scenes/ui/          MainMenu (start scene), PauseMenu, SettingsMenu, HUD (incl. AbilityBar
                    cooldowns, boss bar, AchievementPanel), GameOver, FloorComplete,
                    UpgradeSelection
scripts/            GameManager.gd (autoload: lives, unlocks, gameplay events),
                    SaveManager.gd (autoload: user://save.json), Settings.gd (autoload:
                    volume, fullscreen, key remapping), DungeonAIManager.gd
                    (achievements), RoomManager.gd (transitions,
                    room state), FloorData.gd (floor -> room scenes),
                    CombatStateManager.gd, Fx.gd, GameCamera.gd
scripts/abilities/  Ability base; Carl: KickCombo, ChargedKick, ExplosiveKick;
                    Donut: MagicMissile, ChargedBlast, AreaBurst
scripts/combat/     Hit, HitQuery (instant hitbox queries), MagicProjectile (Donut's bolts),
                    Explosion (radial damage)
resources/upgrades/ Upgrade.gd + one .tres per temporary upgrade
scripts/fx/         Placeholder effects; scripts/Fx.gd autoload (shake, hit stop)
scripts/Audio.gd    Autoload: sound effects and music (SFX/Music buses)
assets/sounds/      Generated sound effects (WAV)   assets/music/  Generated music loops
tools/gen_audio.py  Synthesizes everything in assets/ (make audio)
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
E  entrance   1-9  exit door N      g  Goblin     s  Slime
h  Shield Goblin    a  Armored Slime    v  Cave Bat (flies; spawns in mid-air)
C  chest      F  fountain           S  switch     i  sign     B  boss spawn
X  stairs to the next floor (open once the boss is beaten)
^  spikes (replace the top floor row to make a 1-tile-deep spike pit)
x  explosive barrel   b  crate (holds a potion)   W  cracked wall (solid until broken)
```

Signs take their text from `signs`, in reading order. Write `{jump}`,
`{switch_mode}` and so on (any input action name) to show the player's
current key or controller button. Exit door N leads to
`exits[N-1]`. A full jump clears 3 tiles, so keep steps at 3 tiles or less.
Running jumps reach about 5 tiles across (4 at full height), so pits can be
up to 4 tiles wide. `make test` checks every room's map: it confirms each
exit, chest, switch, fountain, enemy and one-way platform can be reached
from the entrance, and tests
the jump height and pit crossing with real physics.

## Share with the team

To let people play without repo access, run `make playtest` and upload
`build/dcc-playtest.zip` to a private itch.io page. Step-by-step setup is in
[docs/playtesting.md](docs/playtesting.md).

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
make audio  # Regenerate the sound effects and music in assets/ (Python 3)
make playtest  # Release web build without debug keys + build/dcc-playtest.zip for itch.io
make itch ITCH_TARGET=user/game  # Build and upload with butler (see docs/playtesting.md)
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
- **Progression and environment:** specials locked until unlocked; Explosive
  Kick and Magic Burst damage, radius and knockback; beating Floor 1/2
  unlocks each special once; unlocks survive a reload from the save file;
  missing, broken or wrong-typed save files fall back to defaults; the debug
  unlock; every upgrade's effect, stacking, the cooldown floor and exact
  reset; three distinct choices per chest; the chest → pause → pick → resume
  flow; upgrades kept after death but cleared on floor restart; spikes hurt
  the player and kill enemies (credited to the hazard); barrels explode,
  chain and hurt both sides; crates and walls need strong hits; enemy
  collisions damage once; weak hits cause no collision. Tests use their own
  save file, never `user://save.json`.
- **Floor 2:** rooms and exits match the layout doc and every room is
  reachable through doors; every room's map passes the reachability check;
  slimes telegraph and hop at you, only hurt while airborne, avoid spike
  pits and can't hurt once dead; the Mutating Slime's globs land where the
  telegraph shows, standing in a gap is safe, the jump lands on the marker
  and leaves acid, it ignores one-way platforms, phase 2 adds globs, acid and
  minis, and death clears minis and acid and drops potions; Floor 1 →
  Continue → Floor 2 keeps potions and resets lives, health and upgrades;
  beating Floor 2 unlocks the Magic Burst.
- **Menus, settings and saves:** progress and settings share the save file
  without overwriting each other; volume drives the audio buses and
  persists; fullscreen persists; keys remap (keeping controller buttons and
  secondary keys), persist and reset, and pause can't be remapped; the main
  menu hides Continue on a fresh save, offers Continue and floor select after
  progress, and asks before New Game erases progress (keeping settings);
  starting a floor from the menu is a fresh run; the pause menu (and the
  pause key) pauses, resumes, refuses to open over Game Over and leaves to
  the main menu; Game Over and Floor Complete go to the main menu.
- **Dungeon AI:** real collisions and deaths reach the AI; each achievement's
  announcement (title, description, reward) and reward; no repeats within an
  encounter; boosts last exactly this room and the next three; normal kills
  don't count as environmental; a spike kill in F1-05 does; getting hit
  spoils Untouchable; announcements queue and never pause; boosts survive
  death and clear on floor restart.
- **Audio, controller and a full run:** every sound the code plays has a
  file; attacks, hits, deaths, potions, dodges and explosions make sounds;
  music follows the menu, floors and bosses and stops on Game Over; every
  gameplay and menu action has a controller binding, the A button jumps and
  the stick moves; prompts switch between keyboard and controller; and a
  full run plays both floors start to finish along branching paths
  (clearing fights, trials and chests, beating both bosses, continuing to
  Floor 2) and checks the save afterwards.

What the tests can't judge, and still needs checking by hand:

- Game feel and balance: movement, combat, both boss fights (are the
  warnings readable and the fights fair?), slime timing, upgrade strength.
- How the generated sounds and music actually sound, and their volume mix.
  (Tests check that the right sounds are triggered, not what they sound like;
  headless runs don't play music.)
- A real gamepad: controller input is tested with simulated events, not on
  hardware.
- Fullscreen toggling and the browser build on different browsers.

Also try the specials (press U to unlock them), kick goblins into spikes and
each other, pick a few upgrades, and earn each Dungeon AI achievement.

Godot's `.godot/` cache, export credentials, and generated `build/` files are
ignored by Git. The web build also creates `build/.gdignore` so Godot does not
import its own exported files. No server-side state is stored.