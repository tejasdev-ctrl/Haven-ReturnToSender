# RETURN TO SENDER — how the feel is engineered

A design doc can say "camera shake on impact". This file is the part that
actually decides whether the game is fun: which number produces which sensation,
how the numbers interact, and what to turn when something feels wrong.

Everything here is implemented in the code as shipped. Values in `monospace` are
the real values.

---

## 1. The feel target, one line per verb

| Verb | It should feel like | The number that buys it |
| --- | --- | --- |
| Dash | a short, stupid, panicky sidestep | 18 m/s for `0.15 s` = **2.7 m** of travel, `1.2 s` before you can do it again |
| Catch | a gamble that pays out in noise | `0.22 s` window, `2.2 m` reach, `0.6 s` punishment |
| Throw | handing someone a grenade | heat `×1.10`, and a longer charge bends the ball |
| Getting hit | instant, total, funny | round over, `1.0` shake, `0.25×` time for `0.5 s` |

The whole game is one loop: **something comes back at you, slightly faster**.
Every other decision serves that sentence.

## 2. The four numbers

```
BASE_SPEED  = 9.0 m/s      how slow round one is
WALL_HEAT   = 1.08         how fast a rally climbs
CATCH_WINDOW= 0.22 s       how generous survival is
CARRYOVER   = 0.75         how much of the last round you keep
```

Change any of these four and you have a different game. Everything else is
presentation.

## 3. What "faster" actually means

Speed is `BASE_SPEED × heat`, and heat only ever multiplies. The court is 24 m
long, so the crossing time — the number the player's hands care about — is:

| Heat | Speed | 24 m crossing | Time the ball spends inside the 2.2 m catch radius (head-on) |
| --- | --- | --- | --- |
| ×1.0 | 9 m/s | 2.67 s | 489 ms |
| ×2.0 | 18 m/s | 1.33 s | 244 ms |
| ×4.0 | 36 m/s | 0.67 s | 122 ms |
| ×8.0 | 72 m/s | 0.33 s | 61 ms |
| ×12.0 | 108 m/s | **0.22 s** | **41 ms** |

Read the last column twice, because it is the design.

The catch *window* is 0.22 s of open hands. At heat ×1 the window is longer than
the ball's whole transit, so a child can catch by mashing. At heat ×12 the ball
is inside your reach for 41 ms — three physics ticks. The window is then no
longer a reaction time, it is **anticipation**: you press before the ball
arrives and hope. That is exactly the "heroic catch at heat 8 is nearly
impossible" line from the spec, and it falls out of the arithmetic rather than
being scripted.

This is also why the AI's difficulty is not primarily reaction time. Its
`catch_rate` (20 / 55 / 85%) is a *judgement*, rolled once per approach: at high
heat it either committed or it didn't. Reactions alone cannot save you at ×8.

### Why the ball is checked against a swept path, not a point

At ×12 the ball moves 0.9 m per 120 Hz tick. Checking "is the ball within 2.2 m
right now" would let it skip past a player's reach between checks. `ball.gd`
tests the segment from the previous position to the current one, so a catch
either happens or it genuinely did not. Same for the kill test — no clipping
through a capsule at 108 m/s.

### The escalation curve, honestly

The spec's carryover is 0.75 of whatever the previous round ended on. In
practice a round ends around 1.6× the heat it started at, which makes the
per-round growth `1.6 × 0.75 = 1.2`:

| Round | Starts at | Typically ends around |
| --- | --- | --- |
| 1 | ×1.0 | ×1.6 |
| 2 | ×1.2 | ×1.9 |
| 3 | ×1.4 | ×2.3 |
| 4 | ×1.7 | ×2.8 |
| 5 | ×2.1 | ×3.3 |

So the *floor* of each round rises about 20% per round, and the ×12 comet is
reached **inside** a long round-five rally (20 wall bounces at ×1.08 is ×4.6 on
its own), not at the round-five serve. That is a deliberate, playable reading of
the pitch: every round is survivable at the start, and every round can still
become a blur.

If you want the pitch's more theatrical arc — round five opening like a comet —
raise `CARRYOVER` to `0.85` in `scripts/match.gd` (round five then opens near
×3.4) or increase `WALL_HEAT` to `1.12` so rallies climb earlier. Both are
one-line changes and neither breaks anything else.

## 4. The three verbs, mechanically

### Dash

`18 m/s` for `0.15 s` is **2.7 m** of displacement, then `1.2 s` of nothing.
Against a ball crossing the court in 0.22 s, 2.7 m is barely enough to clear a
capsule of radius 0.4 m — you have to move *early*, which means reading the
bounce, which is the skill.

Dash also cancels nothing: you are not invulnerable. Dashing into the ball is
just a faster way to lose. That is on purpose; a dash with i-frames turns this
into a different, softer game.

The dash is legible without any animation: emission jumps from `1.4` to `4.6`
and decays back at `14/s`, so the character flashes for about the length of the
dash and then settles.

### Catch

One key, two meanings, decided by whether you are already holding the ball:

- Not holding → `open_catch()` sets `catch_timer = 0.22`. Any live ball within
  2.2 m during that window is caught.
- Holding → press begins a charge, release throws.

The failure state is the important half: letting the window expire without a
catch costs `0.6 s` of cooldown, during which the key does nothing. That is the
entire risk model. A whiff is not a small mistake; it is a half-second where you
are a spectator.

The catch radius is drawn on the floor as a ring for exactly the `0.22 s` the
window is open. It is the only piece of UI that teaches a timing, and it teaches
it without a tutorial.

### Throw

Charge time `0–0.8 s` maps to `0–1` power. Power does not change the ball's
speed — heat owns that — it changes **curve**: up to `1.5 rad/s` for up to
`0.35 s` of flight, i.e. about 30° of bend at full charge. You curve by holding a
lateral direction while charging; the side is `throw_dir × move_dir`, so it is
symmetric for both players and requires no aiming stick.

At full charge the throw releases itself. This is a deliberate anti-stall: the
ball is never yours to sit on, so a round can never hang. It also gives charging
a hard edge — a full bar is a countdown, not a safe place to wait.

Catching and throwing back multiplies heat by `×1.10` at the moment of release,
so the counter ticks up exactly when the ball leaves your hand and turns around.
That timing is the joke and the reward at once.

## 5. Slow motion budget

One rule: **only one slow motion runs at a time**, and it always ends.
`Game.slowmo()` stamps a token; a later call invalidates the earlier timer, so a
kill during a near-miss cannot leave the game at 0.25× forever.

| Event | Scale | Real duration |
| --- | --- | --- |
| Round lost (flattened) | `0.25×` | `0.5 s` |
| Near miss | `0.3×` | `0.16 s` |
| Wall bounce | none | — |

The near-miss slow-mo is short and quiet on purpose. It happens several times a
rally; anything longer turns into a stutter. It fires at most once per `2.5 s`
per player, only above 24 m/s, and only when the ball passed between 0.95 m and
1.9 m — close enough to feel like a decision, far enough not to be a hit.

The kill slow-mo is longer because it is the punchline, and because the state
machine is already frozen in `ST_POINT` for 1.6 s: the world slows, the banner
lands, and the next round's heat is one number away.

## 6. Shake

Trauma model, not a sine wave: `shake(a)` adds to a value capped at `1.2`, which
decays at `1.7/s`. Offset is `trauma² × 0.55 m`, rotation `trauma² × ~0.01 rad`.
Squaring makes small taps almost invisible and big hits violent, which is the
right curve for impacts.

| Event | Trauma |
| --- | --- |
| Wall bounce | `0.16` (throttled to one per 45 ms) |
| Catch | `0.18` |
| Throw | `0.12` |
| Near miss | `0.25` |
| Flattened | `1.00` |
| Match won | `0.60` |

The wall-bounce throttle matters: at high heat the ball hits several walls per
second, and unbounded shake would make the game unreadable exactly when it is
most exciting.

## 7. Colour, light and glow

Heat `k = (heat − 1) / 11`, and the ball ramps **white → amber → white-hot**:

- `k < 0.45` (heat 1 → 5.9): white `(0.95, 0.97, 1.0)` → amber `(1.0, 0.55, 0.15)`
- `k ≥ 0.45`: amber → white-hot `(1.0, 0.99, 0.95)`

Emission energy goes `1.6 → 9.1` across the same range, and the ball carries its
own `OmniLight3D` whose energy goes `1.0 → 5.0` and whose colour matches. So a
hot ball does not just look bright — it *paints the floor and the players* as it
crosses. That light is the cheapest, most effective thing in the whole look.

The trail is a hand-built ribbon (`ImmediateMesh`, additive, vertex-coloured)
sampled from the last `0.13 s` of motion. Its width tapers from 0.41 m at the
ball to 0.05 m at the tail, and its brightness falls off as `f²`. Because it is
time-based rather than length-based, the trail gets **longer in metres** as the
ball gets faster — the comet is a consequence of the same heat value, not a
separate effect.

The court answers the ball: the floor grid's emission rises with heat
(`0.45 + (heat−1) × 0.16`), the neon trim pulses `+4.5` on every bounce, and the
arena's two lamps are fixed at the two player colours. You can read the speed of
the game from the room, not just the counter.

## 8. Sound

No audio files. `sfx.gd` mixes up to six voices into an `AudioStreamGenerator` at
11025 Hz — deliberately cheap and slightly retro.

| Event | Character |
| --- | --- |
| Wall | 210 Hz, 70 ms, falling pitch |
| Throw | 540 Hz, 90 ms, buzzy, pitch rises with charge (`1.0 + power × 0.5`) |
| Catch | 780 Hz, 110 ms, bright and short |
| Flattened | 95 Hz, 420 ms, falling hard, heavily squared |
| Near miss | 1300 Hz, 50 ms — a hiss, not a hit |
| Sudden death / match | low, long, ugly |

Wall-hit pitch scales with `heat / 4` clamped to `0.6–2.2`, so a fast rally
literally gets higher and tighter. Same information as the colour ramp, through
a different channel.

## 9. Feedback checklist, per event

If you add anything to this game, it should keep these in sync — they are what
make a hit feel like a hit rather than a state change:

| Event | Colour | Motion | Sound | Screen | Text |
| --- | --- | --- | --- | --- | --- |
| Wall bounce | trim pulse | — | pitched blip | small shake | — |
| Catch | catch ring shuts | hands close | bright blip | tiny shake | — |
| Throw | ball heats | curve begins | buzzy blip | tiny shake | — |
| Near miss | — | time slows | hiss | small shake | "NEAR MISS" |
| Flattened | body squashes flat | time crawls | low thud | big shake | "P1 FLATTENED" + flash |
| Round start | — | ball at centre | two blips | — | "ROUND n" + heat |
| Sudden death | walls turn red | walls close | low thud | — | "SUDDEN DEATH" |

## 10. What to change when it feels wrong

| Symptom | Turn this |
| --- | --- |
| Rallies end before they get exciting | `CATCH_WINDOW` 0.26, `CATCH_RADIUS` 2.4 |
| Nothing ever gets fast enough | `CARRYOVER` 0.85, or `WALL_HEAT` 1.12 |
| Too fast, too early — round one is already scary | `CARRYOVER` 0.65, or `WALL_HEAT` 1.05 |
| Dodging is trivial | `DASH_COOLDOWN` 1.4, `DASH_SPEED` 16 |
| Dodging never works | `DASH_SPEED` 20, `DASH_TIME` 0.18 |
| Catches feel like luck | `CATCH_WINDOW` 0.28 (and accept easier survival) |
| AI feels unfair rather than good | lower its `catch_rate` before its `reaction` |
| Hits feel like nothing | raise kill shake and the kill slow-mo, not the flash |
| Screen is noise | cut wall shake to `0.10`, throttle to 80 ms |

## 11. Deliberate omissions

- **No health, no score on the court.** One touch ends a round, so the only
  number that matters is the speed counter. Round pips are the score, and they
  are tiny.
- **No jump.** Verticality would make the catch radius ambiguous and the AI
  prediction a search problem instead of a formula.
- **No split screen.** One fixed camera means both players see the same truth,
  and a shared keyboard means both players are in the same room. That is the
  reason this game exists.
- **No i-frames on dash.** A dodge you can fail is a dodge worth making.
- **No assets.** Every visual is a primitive and every sound is a sine wave.
  The look is carried by emission, glow and motion, which is also why it exports
  to a browser at a size that loads instantly.

## 12. REBOUND — the second ruleset

The original game has no geometry to your body: a hit is a hit. REBOUND adds a
guard, and the guard is the interesting part because **it points where you last
walked**, not where you are looking.

| Number | Value | Why |
| --- | --- | --- |
| Front arc | `dot(from_ball, facing) > -0.18` | ~100° each side, so it wraps past your shoulder. It was 0.15 (~81°) and felt like the guard had a hole in it; only a genuinely behind-the-back hit kills now |
| Guard reach | `hit_radius + 0.16 m` | The guard is a hand's width bigger than the body (0.40 → 0.56 m). A ball that would have clipped your edge bounces instead of killing |
| Block heat | `×1.10` | Same price as a catch-and-return: the rebound is not free |
| Guard cooldown | `0.9 s` | The anti-stall. Without it, standing still and facing your opponent blocks forever |
| Block shake | `0.40` + `2.5°` FOV | Small — it is a save, not a win |

That 0.9 s is what makes the mode escalate with the rest of the game. At heat
×2 a return trip is about 1.3 s each way, so you can block, reset and block
again. At ×8 a trip is 0.33 s: the ball is back on you long before the guard
comes up, so blocking stops being a strategy and becomes a last resort. Same
curve as the catch window, expressed as recovery instead of reaction.

The gate is directional, so movement becomes defensive: backing straight up
keeps your guard on the ball, sidestepping turns your shoulder to it. That is
the whole mode. It costs nothing to learn and it makes the arena feel like it
has a front and a back, which the original game never needed.

## 13. Powerups — temporary lies about the rules

The core loop teaches one thing: the ball is faster than you and it is getting
faster. Powerups exist to make that lesson briefly untrue, which resets your
read of the court every ten seconds or so.

| Pickup | Real effect | Why that number |
| --- | --- | --- |
| OVERCLOCK | run speed `6 → 8.7 m/s` | Enough to outrun a ball you could not have reached, not enough to outrun a ×12 comet |
| SLIP | hit radius `0.40 → 0.26 m` | Cuts the target by a third; a near miss becomes a miss |
| MAGNET | catch reach `2.2 → 3.45 m` | The 0.22 s window is the real limit at high heat, so more reach buys *time*, not certainty |
| SURGE | dash cooldown `1.2 → 0.42 s` | Turns the panic button into a movement style |

All four last `7 s`, spawn every `7–11 s`, cap at two on the floor at once, and
vanish when the round ends. Cross-court travel at heat ×4 is about `0.67 s`, so
a 7 s buff is roughly ten crossings — long enough to build a plan, short enough
that you feel it leaving.

Placement is the balance lever: a pickup never spawns within `3.5 m` of a
player, so collecting one is always a decision to leave your post rather than a
freebie that falls into your lap. MAGNET is the strongest of the four at high
heat and the weakest at low heat, which is the right way round: it rewards the
player who is already surviving.

---

*Verified in headless Godot 4.7.2: serve → bounce → hit → score → next round in
both 2-player and vs-AI; the AI's catch-and-return (heat 1.00 → 1.10); the
0.22 s window expiring into a 0.6 s cooldown; REBOUND front block reflecting a
20 m/s ball to −19.8 m/s at heat ×1.10 with the guard going on cooldown; and a
back hit ending the round; all four powerup effects (SLIP → 0.26 m hit radius,
MAGNET → 3.45 m reach), pickup collection, timed spawn and buff expiry. Not
verified: how it feels in motion — that needs a person with two hands on one
keyboard.*
