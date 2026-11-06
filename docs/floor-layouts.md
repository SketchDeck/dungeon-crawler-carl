# Floor Layouts

Transcribed from the supplied layout document (`DugeonCrawlerCarl floors.pdf`).
This is the source of truth for room types and connections. The document does
not define room geometry, so room interiors use placeholder geometry.

Room types: **Entrance**, **Combat**, **Safe**, **Challenge**, **Boss**.

Arrows are one-way progression (`A → B` means the exit from A leads to B).

## Floor 1

The first four rooms (Entrance → Combat → Safe → Challenge) are marked as the
**Tutorial** section.

```text
                       ┌─ F1-U1 Challenge → F1-U2 Combat → F1-U3 Challenge ─┐
                       │                                                     ↓
F1-01 Entrance → F1-02 Combat → F1-03 Safe → F1-04 Challenge → F1-05 Combat   F1-06 Safe → F1-07 Combat → F1-08 Boss
                       │                                                     ↑
                       └─ F1-D1 Safe → F1-D2 Combat → F1-D3 Challenge ───────┘
```

| Room  | Type      | Exits to       |
|-------|-----------|----------------|
| F1-01 | Entrance  | F1-02          |
| F1-02 | Combat    | F1-03          |
| F1-03 | Safe      | F1-04          |
| F1-04 | Challenge | F1-05          |
| F1-05 | Combat    | F1-U1, F1-D1   |
| F1-U1 | Challenge | F1-U2          |
| F1-U2 | Combat    | F1-U3          |
| F1-U3 | Challenge | F1-06          |
| F1-D1 | Safe      | F1-D2          |
| F1-D2 | Combat    | F1-D3          |
| F1-D3 | Challenge | F1-06          |
| F1-06 | Safe      | F1-07          |
| F1-07 | Combat    | F1-08          |
| F1-08 | Boss      | — (floor end)  |

## Floor 2

| Room  | Type      | Exits to              |
|-------|-----------|-----------------------|
| F2-01 | Entrance  | F2-02                 |
| F2-02 | Challenge | F2-U1, F2-M1, F2-D1   |
| F2-U1 | Combat    | F2-U2                 |
| F2-M1 | Safe      | F2-M2                 |
| F2-D1 | Combat    | F2-D2                 |
| F2-U2 | Safe      | F2-U3                 |
| F2-M2 | Combat    | F2-U2                 |
| F2-D2 | Challenge | F2-M2, F2-D3          |
| F2-U3 | Combat    | F2-U4                 |
| F2-U4 | Challenge | F2-06                 |
| F2-D3 | Combat    | F2-D4                 |
| F2-D4 | Challenge | F2-06                 |
| F2-06 | Safe      | F2-07                 |
| F2-07 | Combat    | F2-08                 |
| F2-08 | Boss      | — (floor end)         |

## Decisions

- Doors only lead forward, following the arrows; entrances are sealed behind
  the player. Rooms still remember their state (cleared, trial done, chest
  opened, fountain used) for the whole floor run.
- Room interiors are placeholder geometry, defined as text maps in each
  scene's `layout` (see README, "Editing rooms"). Floor 1 trials:
  F1-04 climb to the chest, F1-U1 kick three switches, F1-U3 cross the pits,
  F1-D3 defeat the guards.
- The F1-08 boss arena is 30 tiles wide so the whole fight fits on screen,
  with two low platforms for dodging charges and shockwaves. The layout doc
  gives F1-08 no exits, so the floor ends at stairs (`X`) that open once the
  Goblin Brute is beaten.

- **Challenge rooms are the spec's Treasure rooms.** Each one is a trial or
  puzzle (platforming, hazard or combat challenge) that ends in the
  temporary-upgrade choice (pick one of up to three).
