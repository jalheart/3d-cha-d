# Copilot instructions

## Project structure and architecture

- This is a Godot 4.7 project. `project.godot` selects `Scenes/main.tscn` as the entry scene and uses the Mobile renderer and Jolt physics.
- `Scenes/main.tscn` defines the 3D viewer: `Main` owns the camera, light, floor, and `Character` model container. `Scenes/main.gd` coordinates file selection, model replacement, and the specialized components.
- `Scripts/orbit_camera_controller.gd` owns camera orbit, pan, zoom, and target positioning. It is attached to `Camera3D`.
- `Scripts/sidebar_panel.gd` provides non-draggable, collapsible panels with a three-dot menu for Left Sidebar, Right Sidebar, or Bottom Panel placement. Panels assigned to the same location stack, and their locations persist in `user://ui_settings.cfg`. Empty docks are hidden and mouse-transparent. Collapsed side panels shrink to a compact icon-and-menu control; the Bottom Panel keeps its full title and width. `Scripts/fbx_inspector_panel.gd` presents model properties, and `Scripts/fbx_animation_editor_panel.gd` lists and edits animation clips.
- `Scripts/fbx_scene_loader.gd` parses external FBX files at runtime with `FBXDocument.append_from_file()` and `generate_scene()`, reporting failures through a signal. Do not rely on `ResourceLoader` or the editor import cache for arbitrary external FBX paths.
- `Scripts/fbx_scene_exporter.gd` packs the loaded FBX root and its descendants into a reusable `PackedScene`, preserving nodes such as `Skeleton3D`. Export scenes as `.tscn` or `.scn`; temporarily assign scene ownership for packing and restore the live model's ownership afterward.
- `Scripts/fbx_object_export_dialog.gd` exports a selected node subtree as its own `PackedScene`. It supports per-node and per-bone renaming plus case-sensitive bulk find/replace for bone names on the export copy, updates mesh skeleton paths and named skin binds, and leaves animation-track remapping to the Animation Library exporter.
- `Scenes/main.gd` keeps up to ten successfully loaded FBX paths in a `Recent Files` submenu, persisted across launches in `user://recent_files.cfg`.
- The top-level `File` and `View` menus use the default Godot theme. Add `PopupMenu` children directly to `MenuBar` and set their labels with `set_menu_title()`. `View > Text Size` applies extra small/small/default/large font sizes (12/14/16/18 px) to the UI and persists the selection in `user://ui_settings.cfg`.
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

For the manual check, use **View > Text Size** to change the font size and verify the choice persists after restart. Use **File > Load .fbx**, then **File > Export Loaded Scene** to save `.tscn` and `.scn` files. Reload the exported `PackedScene` and verify the imported hierarchy, including `Skeleton3D`, is present. Use **File > Export Object** to select a subtree, bulk-replace bone names, rename its nodes, and verify any skinned mesh still points to the renamed skeleton. Select a clip to test playback, settings, and **Export Library**; verify that animation export can remap paths and save `.res` and `.tres` `AnimationLibrary` resources without changing the source. There is no project-defined test or lint runner.

## Repository conventions

- Keep the scene node names `Camera3D` and `Character` synchronized with the `$Camera3D` and `$Character` references in `Scenes/main.gd`.
- Keep responsibilities in their corresponding scripts: orchestration in `main.gd`, camera behavior in `orbit_camera_controller.gd`, sidebar behavior in `sidebar_panel.gd`, FBX loading in `fbx_scene_loader.gd`, model export in `fbx_scene_exporter.gd`, object export UI in `fbx_object_export_dialog.gd`, and panel-specific UI implementations in their own scripts.
- Runtime UI is assembled in GDScript rather than separate `.tscn` files; connect control signals to focused handler methods and derive inspector data from the loaded scene tree.
- Use Godot 4 APIs and typed GDScript. Source files use UTF-8 and tab indentation.
- Report load and parse failures with `push_error()` and the existing `AcceptDialog` pattern instead of silently ignoring them.
- `.godot/` is generated editor/import data and is ignored by `.gitignore`; do not treat it as source assets.
