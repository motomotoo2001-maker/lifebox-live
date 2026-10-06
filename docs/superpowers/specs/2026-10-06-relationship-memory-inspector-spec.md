# LIFEBOX LIVE — Relationship & Memory Inspector Specification

## Goal

Make social choices readable. When the player chooses a social target, the UI must show the current directed relationship, and the selected resident panel must surface their most recent memory.

## Relationship readout

The SOCIAL panel shows the selected resident's directed values toward the current target:

- affinity;
- trust;
- tension.

Values refresh live, so a completed compliment or argument becomes visible without opening a debug screen.

## Memory readout

The selected resident panel shows the newest retained MemoryEvent:

- memory kind;
- first related resident display name when present;
- positive/negative valence marker.

MemoryStore ownership and eviction behavior remain unchanged.

## Architecture

This is presentation-only inspection:
- no relationship values are mutated by the HUD;
- no memories are consumed or removed;
- RelationshipGraph.get_relationship() and MemoryStore.events() are read-only access paths for presentation.

## Definition of Done

- social target selector and relationship readout stay synchronized;
- unknown relationships render as zero rather than creating graph edges;
- latest memory appears in resident detail panel;
- related resident IDs render as display names;
- positive/negative valence is readable;
- runtime contracts and visual checkpoint remain green.
