# LIFEBOX LIVE — Player Directed Actions Specification

## Goal

Add the first direct player-control layer on top of the autonomous household simulation. Residents keep their UtilityAI, but the player can select one resident and explicitly send them to a household interaction.

## Commands

The selected resident can be ordered to:

- Eat → fridge_main / eat
- Shower → shower_main / shower
- Sleep → that resident's assigned bed_N / sleep_N
- TV → tv_main / watch_tv
- Read → bookshelf_main / read
- Relax → sofa_main / relax

## Authority

- VisualHUD only emits an action identifier.
- VisualSimulationShell maps presentation labels to stable SmartObject IDs.
- SimulationWorld.request_smart_object_action() validates resident, object, interaction, money eligibility, social reservation, and object reservation.
- A valid player command may cancel/replace the resident's current SmartObject action.
- An active social session is not interrupted by a SmartObject player command.
- ActionExecutor remains the only owner of reservation, movement intent, interaction duration, cost/reward, need effects and goal completion.

## Persistence and replay

- Active directed actions are persisted through the existing ActionExecutor snapshot path.
- ReplayLog gains a player_action external-input event with character_id, target_object_id and interaction_id.
- ReplayPlayer applies the event through the same SimulationWorld request API.

## UI

- A DIRECT ACTION bar exposes six buttons below the playfield.
- Buttons act on the currently selected resident.
- Event feed reports accepted/rejected commands.
- Camera briefly focuses the commanded resident.

## Definition of Done

- authoritative direct-action API exists;
- six command buttons are authored;
- selected resident command routing works;
- replacement releases the previous SmartObject reservation;
- social-session ownership is protected;
- player_action replay input is validated and replayable;
- regression suite and visual checkpoint are green.
