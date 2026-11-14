# Return to Sender

A 1v1 neon dodgeball duel for one keyboard. Two players, one court, one ball —
and the ball gets faster every single time it touches anything. Nobody scores.
You survive the round, or you get flattened.

Built for **Godot 4.7** (tested on 4.7.2; the code is 4.4-compatible, so older
4.x editors work too — they will just offer to convert the project). GDScript,
GL Compatibility renderer, exports to the web with thread support off, and needs
no art or audio assets: every mesh, material, court line and sound is generated
at runtime.

---

## Run it

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).
2. Open the folder in the editor (`project.godot`).
3. Press **F5**.

The first launch takes a second while Godot builds its import cache.

## Controls

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | `W A S D` | Arrow keys |
| Dash | `Left Shift` | `.` |
| Hand (catch / charge / throw) | `Space` | `/` |

`Esc` returns to the menu. On the match-over screen, `Enter` starts a rematch.

**Hand does everything.** Not holding the ball → tap opens a 0.22 s catch
window. Holding the ball → press and hold to charge, release to throw.

## Rules

- Best of five. First to three rounds wins. No points, no health — a live ball
  touching you ends the round.
- Heat starts at 1.0, multiplies on every wall hit (×1.08), player hit (×1.12)
  and catch-and-throw-back (×1.10), capped at ×12.
- The next round starts at 75% of the heat the last one ended on. Only a new
  match resets to 1.0, so a match escalates.
- A rally that passes 25 seconds starts closing the walls at 0.5 m/s per side.
- Catching is a 2.2 m proximity grab during the 0.22 s window. Miss it and you
  eat a 0.6 s cooldown.

## Modes

- **2 players** on one keyboard — the real game.
- **VS AI** at ROOKIE / REGULAR / KILLER / IMPOSSIBLE. Tiers differ in aim error,
  reaction delay, catch rate, throw power, and whether the AI leads your movement
  when it throws. IMPOSSIBLE (red) never misreads the bounce, never declines a
  catch, dashes *into* the ball instead of dodging, and returns it cross-court at
  the corner furthest from you. It is beatable only by a hard-angled shot that
  physically outruns it — expect to lose a lot.

## Rulesets

The menu has a **RULES** toggle above the mode buttons.

- **CLASSIC** — the game as designed: any touch from a live ball ends the round.
- **REBOUND** — you have a guard. A ball arriving against your front is knocked
  back (heat ×1.10) and you live; a ball arriving from the side or behind ends
  your round. The guard points the way you last *walked*, so moving is also
  aiming, and a block leaves it down for 0.9 s — you cannot stand still and eat
  a fast rally on your chest. A cone on your chest shows the guard; it dims
  while it is on cooldown.

## Powerups

Every few seconds during a live round a pickup drops somewhere in the court
(max two on the floor at once). Walk over it and you get seven seconds of
something that breaks a rule you just learned:

| Pickup | Effect |
| --- | --- |
| **OVERCLOCK** | +45% run speed |
| **SLIP** | hitbox shrinks from 0.40 m to 0.26 m |
| **MAGNET** | catch reach grows from 2.2 m to 3.45 m |
| **SURGE** | dash cooldown drops from 1.2 s to 0.42 s |

A pickup expires 10 s after it lands (it blinks for the last 2.6). While a buff
is active your foot ring turns its colour and its name and remaining time sit
under your round pips. Every powerup is cleared when the round ends, so nobody
carries an advantage into the next serve.

## Project layout

```
project.godot
export_presets.cfg            web preset, thread support OFF
scenes/    menu · main · arena · player · ball · hud
scripts/   game.gd (autoload) · match · arena · player · ai_player · ball · hud · menu · camera_rig · sfx
.github/workflows/export-web.yml
```

The ball, the players and the court bounds are **not** driven by Godot physics:
`ball.gd` integrates motion itself in sub-steps of ~0.12 m and reflects off
`arena.half_x / half_z`. That is a deliberate change from the original sketch.
It buys three things: no tunnelling at 108 m/s, exact bounces, and an AI whose
prediction uses the identical maths (see `ai_player.gd → _predict()`), so it
never fights engine friction. The numbers from the design are unchanged.

## Tuning cheat sheet

The four numbers that decide how it feels, all in one line each:

| Knob | File | Value |
| --- | --- | --- |
| `BASE_SPEED` | `scripts/ball.gd` | 9.0 m/s |
| `WALL_HEAT` | `scripts/ball.gd` | 1.08 |
| `CATCH_WINDOW` | `scripts/player.gd` | 0.22 s |
| `CARRYOVER` | `scripts/match.gd` | 0.75 |

## Export to the web / itch.io

**From the editor:** Project → Export → *Web* → Export Project. The preset
already writes to `build/web/index.html` with thread support off, which is what
itch.io needs. Zip the *contents* of `build/web`, upload it as an HTML project,
tick "playable in browser", and use 1280×720 as the embed size.

**From CI:** push to `main`. `.github/workflows/export-web.yml` installs Godot
4.4.1 with its export templates, builds the web export, and uploads
`return-to-sender-web.zip` as a workflow artifact.

Web export notes: the project uses the GL Compatibility renderer on purpose —
it is the only renderer that runs reliably in every browser without WebGPU.
Glow still works there, which is most of the look.

## Detailed docs

- `DESIGN.md` — the full design and build spec, saved as written.
- `FEEL.md` — how the feel is actually engineered: every number, why it is that
  number, and what to change when it feels wrong.
