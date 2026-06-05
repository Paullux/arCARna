# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**arCARna** is a Godot 4.x arcade racing game (Asphalt-style: exaggerated speed sensation, permissive drift, spectacular nitro). It is being rebuilt from a Three.js prototype. The primary source document is [`arCARna_godot_briefing.md`](arCARna_godot_briefing.md).

## Non-Negotiable Design Pillars

1. **Arcade physics only** — no realistic simulation. `VehicleBody3D` is **forbidden**. Use `CharacterBody3D` with a scripted fake-physics model.
2. **Speed sensation > real speed** — fabricated with FOV scaling, speed lines, motion blur, screen shake.
3. **Nitro is the central currency** — earned by drift, near-miss, jumps, ring pickups. Segmented gauge (3 segments).
4. **Drift is easy to trigger and auto-rewarded** — it must charge the nitro gauge.
5. **All physics in `_physics_process`** — never in `_process`. Fixed timestep is mandatory for stable behavior.

## Engine & Tools

- **Godot 4.x** — GDScript, `CharacterBody3D`, `move_and_slide()` (no argument in Godot 4 — reads `velocity` property directly).
- **Blender** — modeling and glTF 2.0 export only. No Blender physics.
- **Export format**: glTF Binary (`.glb`) into `res://assets/models/`.

## Architecture

### Scene Tree
```
Main (Node3D)
├── World / Track (Path3D + CSGPolygon3D) / TrafficManager / PickupManager
├── Player (CharacterBody3D)          ← Player.tscn, standalone scene
│   ├── CarMesh (glTF), CollisionShape3D (BoxShape3D — simple)
│   ├── GroundRay (RayCast3D), CameraRig → SpringArm3D → Camera3D
│   ├── GPUParticles3D (nitro, drift smoke L/R)
│   └── AudioStreamPlayer3D (engine, nitro)
├── HUD (CanvasLayer)
└── GameManager (autoload singleton)
```

### GameManager (autoload)
Centralizes: score, combo, nitro, lap, timer, game state. Emits signals (`combo_changed`, `lap_completed`, `nitro_changed`). HUD subscribes to signals — no direct coupling.

### Car Controller Model (`scripts/player.gd`)
"Fake physics": scalar `forward_speed` + heading (`rotation.y`) + grip that aligns actual `velocity` toward heading. Drift = temporarily lowered grip.

Key parameters (all `@export`): `max_speed`, `nitro_speed`, `accel`, `brake_force`, `coast_drag`, `turn_rate`, `grip` (7.0), `drift_grip` (1.6), `gravity`.

Drift trigger: `handbrake and forward_speed > 8.0` OR `abs(steer) > 0.6 and forward_speed > max_speed * 0.6`.

### Camera (`scripts/camera_rig.gd`)
`SpringArm3D` + dynamic FOV (`base_fov=70` → `max_fov=92`) + arm length, both lerped by `forward_speed / max_speed`. Boost multiplier (1.3×) on nitro active.

### Track
Use `Path3D` as master spline — geometry (CSGPolygon3D for v1), traffic AI path, camera lookahead, and lap progression all share this spline. Switch to baked meshes only if detail requires it.

### Traffic (`scripts/traffic_manager.gd`)
Object pooling — reuse `TrafficCar.tscn` instances, never `instantiate()`/`queue_free()` per frame. Cars advance along `Path3D` at fixed speed with random lateral lane offset. 3 discrete lanes.

### Environment
`MultiMeshInstance3D` for crowd/props/streetlights — never instantiate scene nodes in a loop (Three.js anti-pattern to avoid). `WorldEnvironment`: exponential fog, glow enabled, Filmic/ACES tonemap.

## Project File Structure
```
res://
├── scenes/        # Main.tscn, Player.tscn, TrafficCar.tscn, NitroPickup.tscn, HUD.tscn
├── scripts/       # player.gd, camera_rig.gd, traffic_manager.gd, pickup.gd, game_manager.gd
├── assets/
│   ├── models/    # .glb files from Blender
│   ├── textures/
│   ├── audio/
│   └── shaders/   # speed_lines.gdshader, motion_blur, etc.
└── project.godot
```

## Blender → Godot Pipeline

- Scale: **1 Blender unit = 1 Godot meter**. Apply All Transforms (`Ctrl+A`) before export.
- Wheel objects must be **separate meshes** with origin at exact axle center.
- Named: `Body`, `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`, `Spoiler`.
- Materials: Principled BSDF only. Emissive for lights/neons (feeds Godot glow).
- Car front must face `-Z` local in Godot after import; rotate `CarMesh` node, not `CharacterBody3D`, if needed.
- Collision: `BoxShape3D` added manually in Godot. Don't use mesh collision for the car.
- Export: glTF Binary (`.glb`), `Apply Modifiers`, `+Y Up`.

## Input Map (configure in Project Settings)

| Action | Keyboard | Gamepad |
|---|---|---|
| `accelerate` | ↑ / W / Z | RT |
| `brake` | ↓ / S | LT |
| `steer_left` | ← / A / Q | Left stick X− |
| `steer_right` | → / D | Left stick X+ |
| `nitro` | Space / Shift | A / X |
| `drift` | Left Ctrl | B / O |

Use `Input.get_axis()` for steering, `Input.get_action_strength()` for throttle/brake (analog gamepad support automatic).

## Build Order (implement in this sequence, validate feel before advancing)

1. Scripted car controller on flat infinite plane with a cube — **validate feel first**
2. Dynamic camera (SpringArm + FOV + lookahead)
3. Spline track (Path3D + CSGPolygon3D)
4. Blender car mesh (wheels rotate, body rolls in turns)
5. Nitro + boost + HUD gauge
6. Pickups + combo + score
7. Traffic (spawn pool, near-miss detection)
8. Drift VFX (smoke, tire marks, screech)
9. Screen effects (speed lines, glow, motion blur, hit-stop)
10. Audio (engine pitch-scaled, nitro, SFX)
11. Laps / timer / end screen / replay
12. Gamepad vibration + export

## Known Godot 4 Pitfalls

- `move_and_slide()` takes **no velocity argument** — assign `velocity` property then call it.
- `Engine.time_scale = 0.05` for ~80 ms hit-stop on crash, then restore to 1.0.
- Glow requires **both** `WorldEnvironment` glow enabled AND `emission` on material — one alone does nothing.
- Audio `pitch_scale`: always `lerp`, never assign directly (causes audible clicks).
- `MultiMeshInstance3D` for mass props; loop-instantiated nodes kill performance.
- Object pool traffic cars; do not `queue_free()` and re-`instantiate()` constantly.
