# Agent instructions

## Project architecture

- This is a Godot 4.7 project. `project.godot` selects `Scenes/main.tscn` as the entry scene and configures the Mobile renderer and Jolt physics.
- `Scenes/main.tscn` defines the 3D viewer. Its `Main` node owns the `Camera3D`, light, `floor` mesh, `WorldEnvironment`, and `Character` model container; `Scenes/main.gd` coordinates file selection and model replacement.
- `Scripts/view_environment_controller.gd` applies floor visibility, color, and size plus background and ambient-light settings to the `floor` mesh and `WorldEnvironment`. `Scripts/environment_panel.gd` exposes those controls as a dockable Environment panel; values apply live and persist in `user://ui_settings.cfg`.
- `Scripts/orbit_camera_controller.gd`, attached to `Camera3D`, owns orbit, pan, zoom, and target positioning.
- `Scripts/sidebar_panel.gd` provides non-draggable, collapsible panels with a three-dot menu for Left Sidebar, Right Sidebar, or Bottom Panel placement. Panels assigned to the same location stack, and their locations persist in `user://ui_settings.cfg`. Empty docks are hidden and mouse-transparent. Collapsed side panels shrink to a compact icon-and-menu control; the Bottom Panel keeps its full title and width. `Scripts/fbx_inspector_panel.gd` presents model properties, while `Scripts/fbx_animation_editor_panel.gd` lists, plays, and edits animation clips.
- `Scripts/fbx_scene_loader.gd` parses external FBX files at runtime with `FBXDocument.append_from_file()` and `generate_scene()`, and signals failures to the coordinator. Do not rely on `ResourceLoader` or the editor import cache for arbitrary external FBX paths.
- `Scripts/fbx_scene_exporter.gd` packs the loaded FBX root and its descendants into a reusable `PackedScene`, preserving nodes such as `Skeleton3D`. Export scenes as `.tscn`, `.scn`, or a binary `.res`; temporarily assign scene ownership for packing and restore the live model's ownership afterward.
- `Scripts/resource_file_saver.gd` centralizes saving: on desktop it calls `ResourceSaver.save()`, and in Web builds it serializes to a temporary `user://` file and hands the bytes to `JavaScriptBridge.download_buffer()`. Web exports skip save dialogs and download directly; `describe_saved_path()` renders `Downloads/<file>` for messages.
- `Scripts/web_file_picker.gd` implements Web loading: `FileDialog` cannot read the host file system in browsers, so it creates a hidden `<input type="file">` through `JavaScriptBridge.eval()` and returns the selected file's bytes via a `JavaScriptBridge.create_callback()` notification. Guard browser-only behavior with `OS.has_feature("web")`; recent files are disabled there.
- `Scripts/fbx_object_export_dialog.gd` exports a selected node subtree as its own `PackedScene`. The dialog's **Export as** selector chooses a scene (`.tscn` / `.scn`) or a single binary `.res` resource with bundled mesh, skeleton, and animations. It supports per-node and per-bone renaming plus case-sensitive bulk find/replace for bone names on the export copy, updates mesh skeleton paths and named skin binds, and leaves animation-track remapping to the Animation Library exporter.
- `Scenes/main.gd` keeps up to ten successfully loaded FBX paths in a `Recent Files` submenu, persisted across launches in `user://recent_files.cfg`.
- The top-level `File` and `View` menus use the default Godot theme. Add `PopupMenu` children directly to `MenuBar` and set their labels with `set_menu_title()`. `View > Text Size` applies extra small/small/default/large font sizes (12/14/16/18 px) to the UI and persists the selection in `user://ui_settings.cfg`.
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

Web testing is manual: the developer verifies the browser build personally. Do not run browser or Web-export tests yourself (no headless browser automation, no serving the build, no Playwright-style checks); limit automated validation to the Godot headless commands above.

For the manual check, use **View > Text Size** to change the font size and verify the choice persists after restart. Use **File > Load .fbx**, then **File > Export Loaded Scene** to save `.tscn` and `.scn` files. Reload the exported `PackedScene` and verify the imported hierarchy, including `Skeleton3D`, is present. Use **File > Export Object** to select a subtree, choose the scene or binary `.res` format, bulk-replace bone names, rename its nodes, and verify any skinned mesh still points to the renamed skeleton. Select a clip to test playback, settings, and **Export Library**; verify that animation export can remap paths and save `.res` and `.tres` `AnimationLibrary` resources without changing the source. For Web, export with the **Web** preset, serve the build with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, then verify loading through the browser file picker and that exports download instead of opening a save dialog.

## Repository conventions

- Keep the scene node names `Camera3D` and `Character` synchronized with the `$Camera3D` and `$Character` references in `Scenes/main.gd`.
- Keep each concern in its corresponding script: orchestration in `main.gd`, camera behavior in `orbit_camera_controller.gd`, sidebar behavior in `sidebar_panel.gd`, floor/environment application in `view_environment_controller.gd`, environment UI in `environment_panel.gd`, parsing in `fbx_scene_loader.gd`, model export in `fbx_scene_exporter.gd`, platform save/download handling in `resource_file_saver.gd`, browser file picking in `web_file_picker.gd`, object export UI in `fbx_object_export_dialog.gd`, and panel-specific behavior in the inspector and animation editor scripts.
- Runtime UI is assembled in GDScript rather than separate `.tscn` files. Connect controls to focused signal handlers and derive inspector data from the loaded scene tree.
- Use Godot 4 APIs and typed GDScript. Source files use UTF-8 and tab indentation.
- Report load and parse failures with `push_error()` and the existing `AcceptDialog` pattern instead of silently ignoring them.
- `.godot/` contains generated editor/import data and is ignored by `.gitignore`; do not treat it as source assets.
- Update `README.md` with every change. Any new, changed, or removed feature, menu entry, script, scene, requirement, build step, or usage detail must be reflected in `README.md` in the same change, and the **Project architecture** notes above must be kept accurate too.
