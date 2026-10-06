# LIFEBOX LIVE — Player Activity Commands Specification

## Goal

Turn resident inspection into direct life-sim interaction while keeping SimulationWorld authoritative.

## Commands

For the selected resident the HUD exposes:
- EAT;
- SLEEP;
- SHOWER;
- RELAX;
- TV;
- READ.

A command maps to an existing SmartObject + InteractionDefinition. SimulationWorld validates the resident, object, interaction, money eligibility and reservation before starting it.

## Interruption rules

- invalid/unavailable commands are rejected without disturbing the current action;
- a valid direct command may interrupt the resident's current SmartObject action or social session;
- interruption releases previous reservations through existing ActionExecutor/SocialSystem APIs;
- the replacement still follows move-before-interact and normal effect timing.

## Presentation

- HUD emits only activity_requested;
- VisualSimulationShell maps the button to an authoritative interaction request;
- accepted commands focus the selected resident briefly and update the event feed;
- presentation never applies need effects directly.

## Definition of Done

- six command buttons are authored;
- SimulationWorld exposes request_interaction();
- interruption/reservation behavior has integration coverage;
- selected-resident command mapping works;
- full suite remains green;
- real viewport checkpoint shows command controls.
