# LIFEBOX LIVE — Player Interaction Commands Specification

## Goal

Turn resident inspection into actual gameplay: the player can select a resident and request a household action while preserving the autonomous simulation as the authority.

## Commands

The HUD exposes six direct commands:
- EAT → fridge / eat
- RELAX → sofa / relax
- SHOWER → shower / shower
- TV → TV / watch_tv
- READ → bookshelf / read
- SLEEP → the selected resident's own bed

## Simulation authority

VisualHUD only emits a command ID. VisualSimulationShell resolves that ID to an authored SmartObject and asks SimulationWorld.request_interaction().

SimulationWorld accepts the request only when:
- resident exists;
- resident is not in a social reservation;
- movement is idle;
- ActionExecutor is idle;
- SmartObject exists and is available;
- requested interaction exists;
- money requirements are valid.

The normal ActionExecutor then owns reservation, movement intent, arrival, duration, need effects, money effects and goal completion.

A player command never directly changes needs or teleports a resident.

## Replay

ReplayLog and ReplayPlayer support an interaction_request external event containing character_id, object_id and interaction_id, allowing deterministic reconstruction of player-directed actions.

## Definition of Done

- six command buttons exist in the playable HUD;
- selected resident commands route through SimulationWorld.request_interaction();
- busy/invalid requests fail without mutating state;
- valid requests use normal movement + ActionExecutor lifecycle;
- manual command input is valid replay data;
- integration and runtime tests pass;
- vertical visual checkpoint remains readable.
