# Polyrhythm project architecture

## Runtime boundaries

The project keeps scene scripts responsible for wiring Godot nodes while moving
state and policy into testable collaborators.

- `main/main_screen.gd` wires menu controls, stage selection, settings, and audio.
- `main/screen_transition_controller.gd` owns animated screen transitions and
  focus restoration.
- `level/level.gd` coordinates a running level and its scene nodes.
- `level/level_result_service.gd` creates the stable result and timing-trace
  payload from a `RunState`.
- `level/events/level_event_system.gd` indexes event definitions and transforms
  polygon sequences.
- `level/events/event_handler_registry.gd` maps event names to gameplay judgment
  and cue behavior.
- `editor/level_editor.gd` connects editor controls and commands.
- `editor/model/level_document.gd` owns editor data, saved baselines, and dirty
  state.

Timing code under `level/timing/` remains independent from UI and scene
transitions. See [timing_architecture.md](timing_architecture.md) for its detailed
contracts.

## Data flow

```text
stage_catalog.gd -> level YAML -> LevelData -> LevelEventSystem
                                         |             |
                                         v             v
                                     level.gd <- EventHandlerRegistry
                                         |
                                      RunState
                                         |
                                LevelResultService
                                         |
                          ProgressStore + TimingTrace
```

Callers receive deep copies from catalogs and document models where mutation
would otherwise leak across boundaries.

## Adding a stage

1. Add `level/data/level_<number>.yaml` and its imported audio resource.
2. Add the display name, data path, and unlock dialogue to
   `level/data/stage_catalog.gd`.
3. Update `ProgressStore.LAST_STAGE` when the stage extends progression.
4. Add its stage card to `main/main_screen.tscn` until stage cards become fully
   generated from the catalog.
5. Extend `tests/stage_catalog_test.gd` and the timing level regression cases.
6. Run `tests/run_all.sh`.

An unknown stage number resolves to the first stage, so corrupt progress data
cannot point the runtime at a missing file.

## Adding an event

1. Define the event in level YAML with a unique `name` and one-based `at`
   targets. Optional sequence transformation fields are `when_sides` and
   `replace_with`.
2. Register gameplay policy in
   `level/events/event_handler_registry.gd`. Judgment labels and polygon cues
   belong there rather than in `level.gd`.
3. Add an editor template to `EVENT_TYPES` in `editor/level_editor.gd` if the
   event should be authorable through the UI.
4. Add registry and level-data tests. Unknown event names are reported during
   level startup and otherwise ignored safely.

## Diagnostics

`LevelData.validate_detailed()` returns dictionaries with stable `code`,
`field`, `message`, and `source_path` values. UI should display `message` and
`field`; tests and tooling should branch on `code` instead of localized text.

## Verification

Run every headless test from the repository root:

```bash
tests/run_all.sh
```

For a targeted change, run an individual script:

```bash
godot --headless --path . --script res://tests/level_data_test.gd
```

Scene contracts ensure the main screen, level runtime, and editor keep their
required root scripts and node paths. Gameplay and timing regression tests must
also pass before merging changes to the runtime.
