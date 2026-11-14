# Return to Sender

A 1v1 neon dodgeball duel for one keyboard. Two players, one court, one ball —
and the ball gets faster every single time it touches anything. Nobody scores.
You survive the round, or you get flattened.



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



