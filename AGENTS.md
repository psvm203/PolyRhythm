# Godot 4.7 Rhythm Game (PC/Mobile)

## Execution
- Main scene: `level/level.tscn` (defined in `project.godot` under `run/main_scene`).
- Open the project using the `godot` MCP server.

## Architecture & Data Flow
1. **Entry (`level/level.gd`)**
   - Holds the `sides_sequence` array (e.g., `[3,4,3,5,3,3,3,6,4]`), which defines the entire level layout (vertex count per polygon).
   - In `_ready`: Instantiates `ShapeFactory` → builds polygon vertices + centers + exit-edge metadata → passes to `PolygonChain` → produces entrance edges + exit angle offsets → computes per-polygon fly-in start offsets (from previous polygon direction × `fly_in_distance`) → connects `rotator` and `conductor`.
   - Renders **past + current + next** polygons only (future polygons are hidden). Styling: current = rotating/translating full color, next = ghost outline with entrance highlight, past = faded, plus the alignment indicator.

2. **Geometry (`level/geometry/shape_factory.gd`)**
   - `class_name ShapeFactory` (`RefCounted`).
   - Converts vertex counts into arrays of regular polygon vertices, sharing edges between adjacent polygons in the chain.
   - Returns per-polygon metadata: `polygon_centers`, `exit_edge_local_indices`, `sides_counts`.

3. **Chain Metadata (`level/geometry/polygon_chain.gd`)**
   - `RefCounted` (no `class_name`), preloaded in `level.gd`.
   - Aggregates per-polygon entrance edges (world space) and exit-edge angle offsets (angle from polygon center to exit edge midpoint in local frame).

4. **Rotation & Translation (`level/actors/rotator.gd`)**
   - Holds the currently active polygon and accumulates `angle` per frame.
   - Per-polygon angular speed: `ω = TAU / (sides_count * alignment_interval)`, where `alignment_interval = beat_duration / 4 = 60 / bpm / 4`. This produces polyrhythmic rotation rates and ties all alignment moments to the song's BPM.
   - **Phase offset**: the rotation starts at `angle = -TAU / sides` (one step backward) so the first tappable alignment lands exactly at `alignment_interval` seconds after the polygon becomes current — never at t=0.
   - **Fly-in translation**: when a polygon becomes current, it starts at a `start_offset` (computed from the previous polygon direction × `fly_in_distance`) and interpolates linearly to its target position over `transition_duration`. Rotation is around the polygon center; translation is applied to the whole polygon.
   - Alignment is rotation-only (uses the polygon's base center, ignoring the position offset).
   - Provides `get_rotated_polygon()` (offset-applied), `get_rotated_exit_edge_world()` (imagined, offset-free for alignment indicator), `get_alignment_delta()`, and `advance_to_next()`.
   - Emits `polygon_advanced(from, to)` on successful advance (or when the last polygon is left).
   - Sets `completed = true` after the last polygon is left.

5. **Timing (`level/actors/conductor.gd`)**
   - Tracks `_time_in_polygon` and `_next_alignment_index`.
   - The next alignment moment is at `(_next_alignment_index + 1) * alignment_interval` seconds into the polygon — i.e., always one `alignment_interval` ahead of the rotation's current phase.
   - On `tap` input, judges `Perfect` / `Good` based on `|time_past|` vs `perfect_window` / `good_window`. Both windows scale with `alignment_interval` (default `0.5×` and `1.0×` of the interval) so they remain proportional to the BPM.
   - In `_process`, fires `Miss` and calls `rotator.advance_to_next()` when `time_past > good_window`. Miss auto-advances.

6. **Camera (`level/camera.gd`)**
   - Tracks the current polygon's center via the rotator, with position smoothing.
   - No zoom transition on advance; the camera pans smoothly between polygons only.

**Note**: `ShapeFactory` and `PolygonChain` are **not** autoloads; they are instantiated per level build.

## Conventions (DO NOT CHANGE)
- **Renderer**: `mobile`. Stretch mode: `canvas_items` / `expand`. Do not switch to Forward+.
- **UID Files** (`*.uid` and `uid://` lines in `.tscn`): Automatically managed. **Never edit manually**. The `res://` path in scenes is the source of truth for references.
- **Level Definition**: `sides_sequence` and `bpm` are the level sources of truth. Changing them regenerates geometry, rotation rates, and alignment cadence. **There are no external note chart files**.
- **Class Names**: Only use `class_name` for `ShapeFactory`. Do not expose `level.gd`, `rotator.gd`, `conductor.gd`, or `polygon_chain.gd` as class names. `PolygonChain` is reached via `preload`.
- **Judgment Source**: `polygon_advanced` is emitted by the rotator (after `advance_to_next()`) and observed by `level.gd` and `camera.gd`. The conductor drives advance; level reads results.
- **Miss Behavior**: `Miss` from the conductor immediately calls `rotator.advance_to_next()`. Calling `advance_to_next()` on the last polygon flips `completed = true` and stops rotation.

## MCP Tool Usage (Strict Rules)
- **`godot` server**: Expects the Godot binary at `/Applications/Godot.app/Contents/MacOS/Godot`.
- **`godot-mcp-docs` server**: Runs via Docker (`godot-mcp-docs:local`).
  - **Rule**: When answering any Godot-related question, **always** query this MCP server first.
  - **Workflow**: Start with `get_documentation_tree()` to locate the topic, then use `get_documentation_file()` to fetch specific class/tutorial details.
  - **Priority**: Official documentation overrides general AI knowledge.

## Prohibited / Constraints
- **Do not** alter renderer settings, physics engine flags, or UIDs.
