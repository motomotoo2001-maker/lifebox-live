# LIFEBOX LIVE — Visual Simulation Shell Specification

## Goal

Expose the already deterministic autonomous simulation as a readable 9:16 3D dollhouse scene without moving simulation authority into the presentation layer.

## Existing runtime base

- ResidentActor3D: CharacterBody3D + NavigationAgent3D.
- HouseholdBlockout: NavigationRegion3D, floor, six resident spawns, fridge, six beds, shower and sofa.
- Plans 01–05 simulation/persistence/schedule/goal layers remain authoritative.

## Visual direction

- Vertical 720x1280 composition.
- Side-angle dollhouse camera that keeps the full household readable.
- Stylized low-poly resident placeholders first, replaceable by authored character art later.
- Clear color identity per resident.
- Cutaway rooms with simple furniture silhouettes and readable destination zones.
- HUD for time/day, selected resident, schedule, daily goal, needs, money and latest event.

## Presentation authority rule

Presentation may:
- read CharacterState;
- read movement intents;
- visualize action/social state;
- send movement arrival/failure feedback.

Presentation must not:
- mutate needs directly;
- choose Utility AI actions;
- generate goals;
- pay wages;
- change relationships;
- own RNG or save-state authority.

## Camera MVP

- establishing whole-house view;
- focus mode for an interesting resident/event;
- smooth transition;
- minimum focus hold/cooldown to prevent jitter;
- always preserve vertical-safe HUD margins.

## Screenshot workflow

Every major visual task should have a reproducible screenshot scene/harness so progress can be reviewed even before final art.

## Definition of Done

- six visible ResidentActor3D instances;
- readable house blockout;
- real NavigationAgent3D movement visible;
- vertical camera keeps the household framed;
- simulation movement intents drive visual actors;
- visual actors report arrival/failure back to SimulationWorld;
- HUD reflects authoritative state;
- camera focus mode works without rapid jitter;
- extended visual run produces no duplicate actors or stuck presentation state;
- clean Godot CI/headless contract tests.
