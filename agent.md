# Agent instructions

## Project architecture

- This is a Godot 4.7 project. `project.godot` selects `Scenes/main.tscn` as the entry scene and configures the Mobile renderer and Jolt physics.
- `Scenes/main.tscn` defines the 3D viewer. Its `Main` node owns the `Camera3D`, light, floor, and `Character` model container; `Scenes/main.gd` coordinates file selection and model replacement.
- `Scripts/orbit_camera_controller.gd`, attached to `Camera3D`, owns orbit, pan, zoom, and target positioning.
- `Scripts/dockable_panel.gd` supplies reusable drag, snap, and minimize behavior. `Scripts/fbx_inspector_panel.gd` presents model properties, while `Scripts/fbx_animation_editor_panel.gd` lists, plays, and edits animation clips.
- `Scripts/fbx_scene_loader.gd` parses external FBX files at runtime with `FBXDocument.append_from_file()` and `generate_scene()`, and signals failures to the coordinator. Do not rely on `ResourceLoader` or the editor import cache for arbitrary external FBX paths.
- Animation name and loop-mode edits and preview speed apply to the loaded model at runtime; they are not saved to the FBX. Export copies the selected clip's complete `AnimationLibrary` to `.res` or `.tres`, with editable library/animation names, per-track path remapping, bulk find/replace for target paths, and an optional track-root prefix. Export remapping must not modify the source library.

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

For the manual check, use **File > Load .fbx**, then select a clip to test playback, settings, and **Export Library**. Verify the export dialog can rename the library and animations, bulk-replace target track paths, add a root prefix, and save `.res` and `.tres` resources that load as `AnimationLibrary` without changing the source.

## Repository conventions

- Keep the scene node names `Camera3D` and `Character` synchronized with the `$Camera3D` and `$Character` references in `Scenes/main.gd`.
- Keep each concern in its corresponding script: orchestration in `main.gd`, camera behavior in `orbit_camera_controller.gd`, docking mechanics in `dockable_panel.gd`, parsing in `fbx_scene_loader.gd`, and panel-specific behavior in the inspector and animation editor scripts.
- Runtime UI is assembled in GDScript rather than separate `.tscn` files. Connect controls to focused signal handlers and derive inspector data from the loaded scene tree.
- Use Godot 4 APIs and typed GDScript. Source files use UTF-8 and tab indentation.
- Report load and parse failures with `push_error()` and the existing `AcceptDialog` pattern instead of silently ignoring them.
- `.godot/` contains generated editor/import data and is ignored by `.gitignore`; do not treat it as source assets.
