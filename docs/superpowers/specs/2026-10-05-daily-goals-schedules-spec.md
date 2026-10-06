# LIFEBOX LIVE — Daily Goals & Schedules Specification

## Goal

Give each resident a deterministic daily rhythm and small personal objectives so behavior feels intentional rather than purely reactive, while urgent needs remain the safety floor.

## Product behavior

Each resident has:
- a repeating 24-hour schedule;
- a current schedule block;
- 1–3 daily goals are generated; completed goals remain in current-day history while active count may decrease;
- goal progress/completion/failure state;
- deterministic daily rollover.

Schedule examples:
- sleep;
- meal;
- work;
- free time;
- social time.

Goal examples:
- improve comfort;
- talk to a specific resident;
- improve a relationship;
- earn/work;
- relax/have fun;
- complete an optional paid activity.

## AI rule

Schedules and goals modify Utility AI scores. They never directly execute actions.

Critical needs can override schedule/goal preference.

This layer must not require an LLM or network connection.

## Determinism

Same seed + same initial snapshot + same external inputs must generate:
- the same daily goals;
- the same schedule state;
- the same utility modifiers;
- the same final snapshot.

## Persistence

Plan 04 world snapshots must persist:
- schedule state;
- active goals;
- goal progress/status;
- daily rollover state.

Save/load continuation must remain deterministic.

## Scope boundaries

Included:
- daily schedule data and validation;
- per-resident schedule runtime;
- goal definitions/state;
- deterministic goal planner;
- Utility AI score modifiers;
- job schedule hooks;
- social goal hooks;
- persistence;
- multi-day soak.

Deferred:
- physical workplace/commute scenes;
- generated dialogue/LLM goals;
- Story Director/Fate Engine;
- presentation/UI for goals;
- long-term multi-week aspirations.

## Definition of Done

- six residents can run for three simulated days;
- residents exhibit different schedules/goals based on personality and job context;
- urgent hunger/energy can override schedule preferences;
- no resident receives duplicate/invalid daily goals;
- successful matching actions can complete goals; cancel/failure cannot;
- targeted social goals influence actual social partner selection and complete only after a matching social session;
- goal generation occurs once per simulated day;
- save/load mid-day restores exact schedule/goal state;
- same-seed control and restored worlds remain snapshot-identical;
- all existing Plan 01–04 suites remain green.
