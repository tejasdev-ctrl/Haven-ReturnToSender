# RETURN TO SENDER — design & build spec

**Pitch.** Two players, one court, one ball. Every touch makes it faster.
Nobody scores — you survive the round or you don't. The ball keeps its speed
into the next round.

**Type.** 3D, 1v1, keyboard-only, single arena. Godot 4.7 (GDScript, standard
editor — not .NET, which cannot export to web). Web export for itch.io.

---

## 1. Court

| Thing | Value |
| --- | --- |
| Floor | 24 m × 14 m |
| Walls | 5 m high, fully enclosed so the ball can never escape |
| Camera | one fixed camera, roughly `(0, 18, 16)`, tilted ~50° down, FOV 60 |
| Look | near-black floor, emissive neon trim along every wall edge, glow on |

One static camera showing the whole court is deliberate: no split-screen, both
players always visible, and it works on a laptop.

## 2. Players

- Capsule, radius 0.4 m, height 1.8 m, stays on the floor. No jump.
- Run speed 6 m/s, dash 18 m/s for 0.15 s, cooldown 1.2 s.
- Getting hit by a live ball means you lose the round. There is no health.

## 3. The ball — the whole game

- Sphere, radius 0.35 m. Bounce 0.98, friction 0.
- Speed is enforced every frame: `velocity = direction * (BASE_SPEED * heat)`.
  Godot's physics bleeds energy on collisions, so re-normalise rather than
  trusting the bounce. That one line is what makes the escalation reliable.
- `BASE_SPEED = 9 m/s`, heat starts at 1.0, capped at 12.0.

Heat gains:

| Event | Heat |
| --- | --- |
| Wall hit | ×1.08 |
| Player hit | ×1.12 |
| Catch and throw back | ×1.10 |

Round to round: the next round starts at `max(1.0, previous_heat × 0.75)`. A
match escalates — round one is a lob, round five is a blur — but each round is
still survivable. Reset to 1.0 only on a new match.

Sudden death: if a single rally passes 25 seconds, the walls start closing at
0.5 m/s per side until someone dies. No camping, ever.

## 4. The three verbs

**Dodge** — dash key, 0.15 s of speed.

**Hand** — one key does everything. Holding the ball → press to charge, release
to throw. Ball incoming → press to open a 0.22 s catch window (generous on
purpose); if the ball is within 2.2 m and live, you catch it. Miss → 0.6 s
cooldown, which is the punishment.

**Throw** — charge 0–0.8 s for power; longer charge adds curve. Throwing does
not reset heat, it raises it. A heroic catch at high speed hands you a monster.

Catching at heat 8 is nearly impossible — the ball crosses the court faster than
you can react. That is intended: it is the highlight-reel move.

## 5. Controls

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | `W A S D` | Arrow keys |
| Dash | `Left Shift` | `.` (period) |
| Hand (throw / catch) | `Space` | `/` (slash) |

Keys sit next to each player's movement cluster so two people can share one
keyboard without elbowing each other.

## 6. Match flow

Menu → best of 5 (first to 3 rounds) → round intro (1.2 s) → serve from centre
toward a random side → play → hit = round over (slow motion, shake, big text) →
next round at 75% carryover heat → match over → rematch.

## 7. AI — four tiers

The AI predicts where the ball will be by stepping a simulation forward in
0.05 s increments with wall reflections, then moves to the intercept. Difficulty
is aim error, reaction delay, catch rate, and whether it leads your movement.

| Tier | Aim error | Reaction | Catch rate | Throw power | Behaviour |
| --- | --- | --- | --- | --- | --- |
| Rookie | 1.6 m | 0.35 s | 20% | 45% | dashes randomly |
| Regular | 0.5 m | 0.15 s | 55% | 60% | dashes when ball < 3 m |
| Killer | 0.1 m | 0.05 s | 85% | 80% | always dashes, leads your movement |
| Impossible | 0.0 m | 0.02 s | 100% | 100% | never dodges — dashes into the ball; throws cross-court to your far corner |

IMPOSSIBLE is not a cheat: it is the same body you drive, given a perfect read.
It still has to physically cover ground, so a hard-angled shot that crosses the
court faster than it can run (reach deficit > dash distance) beats it. That is
the only hole in it, and it is deliberate — an AI that cannot be scored on is
not a game, it is a wall.

## 8. Feel

- Ball colour driven by heat: white → amber → white-hot, emissive, with a
  motion trail.
- HUD: giant `×7.4` SPEED counter, round pips, tier name.
- Screen shake on every impact and every death.
- `Engine.time_scale = 0.25` briefly on a kill or a near miss, then back to 1.
- Wall flash on every ball bounce — cheap, and it makes rallies readable.
- Synthesised beeps, no audio files.

## 9. Project layout

```
project.godot
export_presets.cfg          # Web preset, thread support OFF
.gitignore                  # ignores .godot/ and build output
README.md
.github/workflows/export-web.yml
scenes/  main · arena · player · ball · hud · menu
scripts/ ball.gd · player.gd · ai_player.gd · match.gd · hud.gd · menu.gd
```

Core of the ball, as originally sketched:

```gdscript
extends RigidBody3D

const BASE_SPEED := 9.0
const MAX_HEAT := 12.0
var heat := 1.0
var live := false
var held_by: Node3D = null

func _physics_process(_delta: float) -> void:
    if held_by:
        global_position = held_by.global_position + Vector3.UP * 1.2
        return
    if live and linear_velocity.length() > 0.01:
        linear_velocity = linear_velocity.normalized() * (BASE_SPEED * heat)

func _on_body_entered(body: Node) -> void:
    if not live: return
    if body.is_in_group("court"):
        heat = minf(heat * 1.08, MAX_HEAT)
    elif body.is_in_group("player"):
        heat = minf(heat * 1.12, MAX_HEAT)
```

And the catch, in `player.gd`:

```gdscript
func start_catch() -> void:
    catch_timer = 0.22

func _physics_process(delta: float) -> void:
    if catch_timer > 0.0:
        catch_timer -= delta
        if ball.live and global_position.distance_to(ball.global_position) < 2.2:
            ball.held_by = self
            ball.live = false
            holding_ball = true
```

> **Build note.** The shipped `ball.gd` keeps every number above but integrates
> motion by hand instead of using a `RigidBody3D`. At ×12 the ball moves 1.8 m
> per physics tick, which is five times its own diameter: a rigid body needs
> continuous collision detection to survive that, still loses energy to the
> solver, and — the real problem — makes the AI's forward simulation disagree
> with reality. A hand integrator with sub-steps smaller than the ball's radius
> gives exact reflections, no tunnelling, and one source of truth shared by the
> ball and the AI. The spec's own line ("re-normalise instead of trusting the
> bounce") is the same argument taken to its conclusion.

## 10. Shipping

1. Push the folder to a GitHub repo — `.gitignore` keeps the editor cache out.
2. Export with the Web preset, thread support off, output `index.html`, into an
   empty folder.
3. Zip the contents of that folder.
4. itch.io → new project → HTML → upload the zip → tick "playable in browser" →
   embed size 1280×720.
5. Or skip 2–3: the GitHub Action builds the zip on every push.

**Tuning cheat sheet** — the four numbers that decide how it feels:
`BASE_SPEED` (9), wall heat (8%), the 0.22 s catch window, and the 0.75
carryover.
