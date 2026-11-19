# Copilot instructions

## Project structure and architecture

- This is a Godot 4.7 project. `project.godot` selects `Scenes/main.tscn` as the entry scene and uses the Mobile renderer and Jolt physics.
- `Scenes/main.tscn` defines the 3D viewer: `Main` owns the camera, light, floor, and `Character` model container. Its root script is `Scenes/main.gd`.
- `Scenes/main.gd` handles camera orbit, pan, and zoom, and creates the runtime UI in a `CanvasLayer`. The inspector and animation editor are custom draggable panels that snap to screen edges or each other and can be minimized.
- FBX files are selected from the filesystem and parsed at runtime with `FBXDocument.append_from_file()` and `generate_scene()`. The generated model replaces the children of `Character`; do not rely on `ResourceLoader` or the editor import cache for arbitrary external FBX paths.
- The inspector recursively examines the generated scene tree for mesh instances, material textures, node scales, and `AnimationPlayer` clips. Animation edits (rename, loop mode, and preview speed) apply to the loaded model at runtime and are not written back to the FBX.

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

For the manual check, use **File > Load .fbx**, then select a clip to open its editor and test playback and settings. There is no project-defined test or lint runner.

## Repository conventions

- Keep the scene node names `Camera3D` and `Character` synchronized with the `$Camera3D` and `$Character` references in `Scenes/main.gd`.
- Runtime UI is assembled in GDScript rather than separate `.tscn` files; connect control signals to the existing handler/helper methods and keep inspector data derived from the loaded scene tree.
- Use Godot 4 APIs and typed GDScript. Source files use UTF-8 and tab indentation.
- Report load and parse failures with `push_error()` and the existing `AcceptDialog` pattern instead of silently ignoring them.
- `.godot/` is generated editor/import data and is ignored by `.gitignore`; do not treat it as source assets.
