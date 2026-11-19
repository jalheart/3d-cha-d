# Copilot instructions

## Project structure and architecture

- This is a Godot 4.7 project. `project.godot` selects `Scenes/main.tscn` as the entry scene and uses the Mobile renderer and Jolt physics.
- `Scenes/main.tscn` defines the 3D viewer: `Main` owns the camera, light, floor, and `Character` model container. `Scenes/main.gd` coordinates file selection, model replacement, and the specialized components.
- `Scripts/orbit_camera_controller.gd` owns camera orbit, pan, zoom, and target positioning. It is attached to `Camera3D`.
- `Scripts/dockable_panel.gd` provides reusable drag, snap, and minimize behavior. `Scripts/fbx_inspector_panel.gd` presents model properties, and `Scripts/fbx_animation_editor_panel.gd` lists and edits animation clips.
- `Scripts/fbx_scene_loader.gd` parses external FBX files at runtime with `FBXDocument.append_from_file()` and `generate_scene()`, reporting failures through a signal. Do not rely on `ResourceLoader` or the editor import cache for arbitrary external FBX paths.
- `Scripts/fbx_scene_exporter.gd` packs the loaded FBX root and its descendants into a reusable `PackedScene`, preserving nodes such as `Skeleton3D`. Export scenes as `.tscn` or `.scn`; temporarily assign scene ownership for packing and restore the live model's ownership afterward.
- `Scenes/main.gd` keeps up to ten successfully loaded FBX paths in a `Recent Files` submenu, persisted across launches in `user://recent_files.cfg`.
- Animation name and loop-mode edits and preview speed apply to the loaded model at runtime; they are not written back to the FBX. Export copies the selected clip's complete `AnimationLibrary` to `.res` or `.tres`, with editable library/animation names, per-track path remapping, bulk find/replace for target paths, and an optional track-root prefix. Export remapping must not modify the source library.

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

For the manual check, use **File > Load .fbx**, then use **File > Export Loaded Scene** to save `.tscn` and `.scn` files. Reload the exported `PackedScene` and verify the imported hierarchy, including `Skeleton3D`, is present. Select a clip to test playback, settings, and **Export Library**; verify that animation export can remap paths and save `.res` and `.tres` `AnimationLibrary` resources without changing the source. There is no project-defined test or lint runner.

## Repository conventions

- Keep the scene node names `Camera3D` and `Character` synchronized with the `$Camera3D` and `$Character` references in `Scenes/main.gd`.
- Keep responsibilities in their corresponding scripts: orchestration in `main.gd`, camera behavior in `orbit_camera_controller.gd`, panel mechanics in `dockable_panel.gd`, FBX loading in `fbx_scene_loader.gd`, model scene export in `fbx_scene_exporter.gd`, and the two panel-specific UI implementations in their own scripts.
- Runtime UI is assembled in GDScript rather than separate `.tscn` files; connect control signals to focused handler methods and derive inspector data from the loaded scene tree.
- Use Godot 4 APIs and typed GDScript. Source files use UTF-8 and tab indentation.
- Report load and parse failures with `push_error()` and the existing `AcceptDialog` pattern instead of silently ignoring them.
- `.godot/` is generated editor/import data and is ignored by `.gitignore`; do not treat it as source assets.
