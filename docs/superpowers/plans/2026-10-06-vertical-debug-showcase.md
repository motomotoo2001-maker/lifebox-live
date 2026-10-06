# Vertical Debug Showcase Plan

**Goal:** Add a real Godot-rendered 9:16 project showcase that makes simulation state visible during development.

## Scope
- 720x1280 vertical debug scene.
- Six resident cards.
- House-zone overview.
- Current simulated time/day.
- Resident action, money, needs, active schedule block and daily goals.
- Separate from production main scene.
- Renderable headlessly to PNG for progress screenshots.

## Tasks
1. Add reusable debug showcase renderer.
2. Add standalone showcase scene/script.
3. Add deterministic sample resident state matching current Plan 05 systems.
4. Add headless screenshot capture entrypoint.
5. Keep production simulation untouched.
