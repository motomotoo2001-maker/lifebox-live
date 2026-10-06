# LIFEBOX LIVE — Playable Shell & Resident Roster Specification

## Goal

Make the current simulation launch as a normal Godot game and provide an always-visible six-resident roster for direct inspection.

## Main application

- F5 launches a dedicated LIFEBOX LIVE main scene.
- Main scene hosts the existing household simulation scene.
- Debug capture support remains available through the underlying showcase scene.

## Resident roster

- Six compact resident buttons are authored in the HUD.
- Buttons show number + display name.
- Selected resident button is highlighted.
- Clicking a button emits resident_requested and uses the same selection path as 3D clicking and 1–6 hotkeys.
- Buttons never mutate simulation state directly.

## Definition of Done

- project.godot has a main scene;
- main scene loads and instantiates;
- six roster buttons exist;
- HUD emits resident_requested;
- VisualSimulationShell consumes the signal through select_resident();
- runtime contracts remain green;
- vertical HUD remains readable.
