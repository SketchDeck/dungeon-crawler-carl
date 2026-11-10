# Sharing a playtest build

Teammates play in their browser on a private itch.io page. They don't need
repo access, Godot or an install.

Playtest builds are release builds with the debug keys (N to skip a room,
U to unlock the specials) turned off. Use `make web` / `make serve` when
you want the debug keys for your own testing.

## Build

```sh
make playtest
```

This exports `build/playtest/` and zips it to `build/dcc-playtest.zip`
(about 11 MB), with `index.html` at the top of the zip, which is the layout
itch.io expects.

## First upload (once, in the browser)

1. Sign in at <https://itch.io> (or create a free account), then open
   **Upload new project** from the menu under your profile.
2. **Title:** e.g. "Dungeon Crawler Carl prototype". **Kind of project:**
   **HTML**.
3. **Uploads:** upload `build/dcc-playtest.zip` and tick **This file will be
   played in the browser**.
4. **Embed options:**
   - Viewport dimensions: **960 × 640**.
   - Tick **Fullscreen button**.
   - Leave **SharedArrayBuffer support** off (the build doesn't use threads).
5. **Visibility & access**, pick one:
   - **Draft:** only you can see it, and you can share the secret preview
     link (the simplest option).
   - **Restricted:** only invited itch.io accounts can play it, or set a
     password to share with the team.

   Don't choose Public: this is a fan prototype built on someone else's
   books and characters.
6. Save, then open the page and click the game to start. Browsers keep the
   sound off until you click.

## Updating the build

Either upload the new `build/dcc-playtest.zip` on the project's **Edit
game** page (replacing the old file), or let `butler` do it in one command:

1. Install butler, itch.io's upload tool, from
   <https://itch.io/docs/butler/installing.html> and put it on your PATH.
2. Run `butler login` once. It opens the browser to authorize.
3. From then on:

   ```sh
   make itch ITCH_TARGET=your-itch-username/your-project-url-name
   ```

   This builds, then pushes to the page's `html5` channel. The first butler
   push creates a new upload. On the Edit game page, tick **This file will be
   played in the browser** for it and delete the old manual upload. Later
   pushes update it in place, and the page's link never changes.

## What testers should know

- Saves (completed floors, unlocks, settings) are stored in their browser for
  that site. Clearing site data resets them.
- Keyboard: A/D or arrows, Space, J/K/L, Tab, Shift, H, E, Esc to pause.
  Keys can be remapped in Settings. Controllers work too.
- Useful things to report: where they died, whether boss warnings were
  readable, anything that felt unfair, and any room where they got stuck.
