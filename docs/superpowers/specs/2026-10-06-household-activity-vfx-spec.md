# LIFEBOX LIVE — Household Activity VFX Specification

## Goal

Make autonomous actions visible in the environment, not only as text above residents.

## Presentation feedback

- watch_tv activates an emissive TV screen and blue local glow;
- shower / wash_up activates a cool bathroom activity light;
- read activates a warm bookshelf/reading glow.

The simulation remains authoritative. Effects are derived each presentation sync from current_action_id and never change needs, goals, relationships, RNG, reservations or action timers.

## Scene ownership

All activity VFX nodes are authored under HouseholdBlockout/Visuals/ActivityFX so they remain editable in Godot.

## Definition of Done

- ActivityFX container and three effects exist in the scene;
- HouseholdBlockout exposes set_activity_visuals();
- VisualSimulationShell drives the effects from authoritative actions;
- VFX turn off when no matching action exists;
- runtime scene contracts cover the new nodes/method;
- full tests remain green;
- a real viewport checkpoint is captured.
