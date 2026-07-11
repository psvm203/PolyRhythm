# Godot 4.7 Rhythm Game (PC/Mobile)

## Execution
- Main scene: `level/level.tscn` (defined in `project.godot` under `run/main_scene`).
- Open the project using the `godot` MCP server.

## Architecture & Data Flow
1. **Entry (`level/level.gd`)**
   - Holds the `sides_sequence` array (e.g., `[3,4,3,5,3,3,3,6,4]`), which defines the entire level layout (vertex count per polygon).
   - In `_ready`: Instantiates `ShapeFactory` → generates polygon vertices → passes to `PathFinder` → builds paths → connects `player` and `conductor`.

2. **Geometry (`level/shape_factory.gd`)**
   - `class_name ShapeFactory` (`RefCounted`).
   - Converts vertex counts into arrays of regular polygon vertices.

3. **Pathfinding (`level/path_finder.gd`)**
   - `class_name PathFinder` (`RefCounted`).
   - Finds the longest path across shapes using shared exit edges.
   - Simultaneously generates the note index list for the conductor.

4. **Timing (`level/conductor.gd`)**
   - Handles note timing and judgment (`Perfect` / `Good` / `Miss`).
   - Exports judgment windows (`perfect_window`, `good_window`, `seconds_per_edge`).

5. **Player (`player/player.gd`)**
   - Animated dot following the generated path.
   - Maintains the elapsed time clock.

**Note**: `ShapeFactory` and `PathFinder` are **not** autoloads; they are instantiated per level build.

## Conventions (DO NOT CHANGE)
- **Renderer**: `mobile`. Stretch mode: `canvas_items` / `expand`. Do not switch to Forward+.
- **UID Files** (`*.uid` and `uid://` lines in `.tscn`): Automatically managed. **Never edit manually**. The `res://` path in scenes is the source of truth for references.
- **Level Definition**: `sides_sequence` is the sole source of truth. Changing it regenerates geometry, guided paths, and note edges. **There are no external note chart files**.
- **Class Names**: Only use `class_name` for `ShapeFactory` and `PathFinder`. Do not expose `level.gd` or `conductor.gd` as class names.

## MCP Tool Usage (Strict Rules)
- **`godot` server**: Expects the Godot binary at `/Applications/Godot.app/Contents/MacOS/Godot`.
- **`godot-mcp-docs` server**: Runs via Docker (`godot-mcp-docs:local`).
  - **Rule**: When answering any Godot-related question, **always** query this MCP server first.
  - **Workflow**: Start with `get_documentation_tree()` to locate the topic, then use `get_documentation_file()` to fetch specific class/tutorial details.
  - **Priority**: Official documentation overrides general AI knowledge.

## Prohibited / Constraints
- **Do not** alter renderer settings, physics engine flags, or UIDs.
