# LIFEBOX LIVE — Direct Social Commands Specification

## Goal

Let the player influence relationships while preserving the same authoritative social-session and memory systems used by autonomous AI.

## Controls

The selected resident gets three social commands aimed at their closest known resident:
- CHAT;
- COMPLIMENT;
- ARGUE.

The HUD displays the target name above the buttons.

## Authority

SimulationWorld.request_social_interaction():
- validates initiator, target and registered action;
- rejects self/unknown targets;
- optionally interrupts SmartObject or social actions;
- releases old reservations through existing APIs;
- starts the registered SocialSystem action;
- relationship and memory effects happen only when SocialSystem completes the session.

## Definition of Done

- three social buttons are authored;
- closest resident target is visible;
- SocialSystem exposes safe registered-action start;
- SimulationWorld exposes direct social request;
- integration tests verify replacement, outcome, memory and reservation release;
- full suite remains green;
- 9:16 capture shows the social controls.
