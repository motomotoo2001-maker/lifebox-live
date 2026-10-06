# Visual Simulation Shell Implementation Plan

**Goal:** Turn the verified simulation into a visible 9:16 3D household shell with real resident actors, movement, camera and HUD.

## Task 1 — Visible ResidentActor3D
- Extend runtime contract test.
- Add body/head/shadow/name visual nodes.
- Add display name/color API.
- Face movement direction.
- Keep CharacterBody3D/NavigationAgent3D contract unchanged.
- Render screenshot checkpoint.

## Task 2 — Household visual blockout
- Add cutaway room zones and wall/furniture silhouettes.
- Keep authored NavigationMesh and destination markers unchanged.
- Add visual contract test.

## Task 3 — Vertical camera rig
- Add side-angle 9:16 Camera3D rig.
- Whole-house framing contract.
- Screenshot checkpoint.

## Task 4 — VisualSimulationShell binding
- Instantiate six actors from authoritative resident roster.
- Spawn at existing markers.
- Map movement intent target positions into ResidentActor3D.
- Forward arrival/failure to SimulationWorld.
- Prevent duplicate actors and duplicate movement dispatch.

## Task 5 — HUD
- Day/time.
- Selected resident identity.
- schedule/goal.
- needs/money.
- latest event/status strip.

## Task 6 — Screenshot harness
- Reproducible capture path for current visual shell.
- Store checkpoint metadata in Notion/Drive.

## Task 7 — Camera Director MVP
- Establishing/focus modes.
- Interest target input.
- smooth movement.
- hold/cooldown/hysteresis.

## Task 8 — Visual soak
- six residents;
- extended movement;
- no duplicate actor mapping;
- no stuck presentation ownership;
- clean CI;
- final screenshot.
