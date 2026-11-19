# Agent instructions

## Project architecture

- This is a Godot 4.7 project. `project.godot` selects `Scenes/main.tscn` as the entry scene and configures the Mobile renderer and Jolt physics.
- `Scenes/main.tscn` defines the 3D viewer. Its `Main` node owns the `Camera3D`, light, floor, and `Character` model container; `Scenes/main.gd` is attached to the root.
- `Scenes/main.gd` handles camera orbit, pan, and zoom. It also builds the runtime UI in a `CanvasLayer`, including draggable, edge-snapping, minimizable inspector and animation panels.
- FBX files are selected from the filesystem and parsed at runtime with `FBXDocument.append_from_file()` and `generate_scene()`. The generated model replaces the children of `Character`. Do not use `ResourceLoader` or rely on the editor import cache for arbitrary external FBX paths.
- The inspector recursively examines the loaded scene for meshes, material textures, scales, and `AnimationPlayer` clips. Animation name, loop mode, and preview-speed edits apply to the loaded model at runtime; they are not saved to the FBX.

## SOLID design requirements

Apply SOLID when designing or changing project code, keeping the design proportional to the actual need.

- **Single Responsibility:** Keep camera control, FBX loading, scene inspection, animation editing, and dock-panel behavior as separate responsibilities. Extract focused scripts or helpers as these areas grow instead of expanding one script to own every concern.
- **Open/Closed:** Add model formats and inspector capabilities through focused loaders or extensions while preserving existing viewer behavior.
- **Liskov Substitution:** Preserve the Godot node, resource, and signal contracts that callers rely on.
- **Interface Segregation:** Expose small, purpose-specific methods and signals; avoid requiring consumers to depend on unrelated viewer, loader, or UI operations.
- **Dependency Inversion:** Keep higher-level viewer behavior independent from concrete filesystem and parser details where a useful Godot abstraction can be passed in.

## Build and validation

Use Godot 4.7.2. The executable configured in `.vscode/settings.json` is workstation-specific; use `godot` below if it is on `PATH`, or substitute the local executable.

```sh
# Scan/import the project and catch script or scene errors.
godot --headless --path . --editor --quit

# Start the main scene headlessly as a startup smoke test.
godot --headless --path . --quit-after 2

# Run the viewer for a manual FBX/animation check.
godot --path .
```

For the manual check, use **File > Load .fbx**, then select a clip to open its editor and test playback and settings.

## Repository conventions

- Keep the scene node names `Camera3D` and `Character` synchronized with the `$Camera3D` and `$Character` references in `Scenes/main.gd`.
- Runtime UI is assembled in GDScript rather than separate `.tscn` files. Connect controls to focused signal handlers and derive inspector data from the loaded scene tree.
- Use Godot 4 APIs and typed GDScript. Source files use UTF-8 and tab indentation.
- Report load and parse failures with `push_error()` and the existing `AcceptDialog` pattern instead of silently ignoring them.
- `.godot/` contains generated editor/import data and is ignored by `.gitignore`; do not treat it as source assets.
