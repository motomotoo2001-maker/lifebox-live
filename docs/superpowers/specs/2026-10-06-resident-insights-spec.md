# LIFEBOX LIVE — Resident Insights Panel Specification

## Goal

Expose the simulation depth already running behind each resident so selecting a person feels like inspecting a living character rather than only four need bars.

## Panel

A new RESIDENT INSIGHTS panel shows:

- Career: job ID, hourly pay and shift window.
- Household economy: daily shared bills and current arrears.
- Closest relationship: resident name plus affinity, trust and tension.
- Recent memory: latest memory kind, related resident, emotional valence and importance.

The existing daily goal line also shows active goal progress as a percentage.

## Selection semantics

The panel follows the same selected resident as the roster, keyboard selection and 3D click selection. It is read-only presentation. It never mutates jobs, relationships, memories, money or goals.

## Relationship ranking

For presentation only, the closest outgoing relationship is ranked deterministically using:
affinity + 0.6 × trust − 0.8 × positive tension.

Ties are resolved by resident ID.

## Definition of Done

- authored InsightPanel is present in the vertical HUD;
- career/economy/relationship/memory helpers are deterministic;
- active goal progress is visible;
- a runtime fixture verifies job, bills, closest relationship and recent memory text;
- all existing tests stay green;
- real viewport capture remains readable.
