# LIFEBOX LIVE — Character Art & Interaction Anchors Specification

## Goal

Improve the six-resident dollhouse so residents read as distinct stylized people and use furniture from believable positions, while preserving deterministic simulation authority.

## Character presentation

Each ResidentActor3D keeps the same CharacterBody3D movement contract but gains:
- visible hands and shoes;
- a small clothing accent;
- profile-dependent skin tones, hair silhouettes and accessories;
- stronger selected-state readability;
- existing idle/walk/interact/social animation states remain presentation-only.

## Interaction anchors

The simulation continues to own SmartObject interaction points. The presentation adapter may offset the visual navigation target so a resident stands beside or in front of furniture instead of inside it.

Presentation anchors:
- fridge: stand in front of the door;
- shower: stand at the opening;
- beds: stand at the bedside/foot instead of the mattress center;
- sofa: deterministic multi-resident slots.

Arrival still reports the authoritative SmartObject ID and cannot change gameplay outcomes.

## Inspection controls

Extend the existing inspection controls:
- 1–6 selects residents;
- Space pauses/resumes presentation-side simulation advance;
- +/- changes simulation time scale through SimulationClock;
- Escape returns the camera to the establishing view.

HUD shows:
- selected resident current action;
- current simulation speed;
- existing needs, schedule, goal and money.

## Definition of Done

- character silhouettes are visibly more distinct;
- furniture overlap is reduced at fridge/shower/bed/sofa interactions;
- time-scale controls clamp through SimulationClock;
- selected resident action is visible in HUD;
- Escape restores overview;
- no presentation code mutates simulation needs/goals/relationships/RNG directly;
- runtime contracts pass;
- real 9:16 Godot screenshot is captured.
