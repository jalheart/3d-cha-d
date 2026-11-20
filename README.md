# 3DChaD

A Godot 4.7 desktop tool for loading, inspecting, and exporting external FBX models at runtime. It acts as a lightweight 3D model viewer with an animation editor and a repositionable panel workspace.

## Features

- **Load `.fbx` files at runtime** — parsed with `FBXDocument.append_from_file()` / `generate_scene()`, independent of the editor import cache.
- **Orbit camera** — orbit, pan, zoom, and target positioning around the loaded model.
- **Inspector panel** — shows properties of the selected node in the loaded scene tree.
- **Animation editor** — lists clips, plays previews, and edits animation name, loop mode, and preview speed.
- **Repositionable panels** — Left Sidebar, Right Sidebar, or Bottom Panel placement via a three-dot menu; empty docks hide, collapsed side panels shrink to an icon, and the layout persists.
- **Scene export** — pack the loaded model (including `Skeleton3D`) into a reusable `.tscn` or `.scn`.
- **Object export** — export any node subtree with per-node/per-bone renaming and case-sensitive bulk find/replace for bone names.
- **Animation library export** — export clips to `.res` / `.tres` with track-path remapping, bulk path find/replace, and an optional track-root prefix; the source library is never modified.
- **Recent files** — the last ten successfully loaded FBX paths, persisted across launches.
- **Text size** — extra small / small / default / large UI font sizes, persisted across launches.

## Requirements

- [Godot 4.7.2](https://godotengine.org/) (standard or .NET build). The executable path configured in `.vscode/settings.json` is workstation-specific; substitute your local path or use `godot` from `PATH`.
- Windows build uses the **Mobile** renderer with **Jolt Physics** and the `d3d12` driver (see `project.godot`).

## Running

```sh
# Scan/import the project and catch script or scene errors.
godot --headless --path . --editor --quit

# Start the main scene headlessly as a startup smoke test.
godot --headless --path . --quit-after 2

# Run the viewer.
godot --path .
```

## Usage

| Menu | Action |
| --- | --- |
| **File > Load .fbx** | Open an external FBX model. |
| **File > Recent Files** | Reopen one of the last ten loaded models. |
| **File > Export Loaded Scene...** | Save the model as `.tscn` or `.scn`. |
| **File > Export Object...** | Export a selected node subtree with renaming options. |
| **File > Export Library** (animation panel) | Save the selected clip's `AnimationLibrary` to `.res` or `.tres`. |
| **View > Text Size** | Change the UI font size (persists across restarts). |

## Project structure

```
project.godot          # Godot project config (entry scene, renderer, physics)
export_presets.cfg     # Windows Desktop export preset
Scenes/
  main.tscn            # Entry scene: camera, light, floor, Character container
  main.gd              # Coordinates UI, file selection, model replacement, menus
Scripts/
  orbit_camera_controller.gd   # Orbit / pan / zoom camera control
  sidebar_panel.gd             # Collapsible, repositionable dock panels
  fbx_inspector_panel.gd       # Model property inspector
  fbx_animation_editor_panel.gd# Animation clip list, playback, and editing
  fbx_scene_loader.gd          # Runtime FBX parsing
  fbx_scene_exporter.gd        # Packs the model into a PackedScene
  fbx_object_export_dialog.gd  # Subtree export with renaming/bulk replace
  animation_library_export_dialog.gd # AnimationLibrary export UI
assets/models/         # Sample models and exported resources
agent.md               # Architecture, design rules, and validation workflow for AI agents
```

## Design rules

Project code follows SOLID principles — see the **SOLID design requirements** section of [`agent.md`](agent.md). Each concern lives in its own script, runtime UI is assembled in GDScript rather than separate `.tscn` files, and load/parse failures are reported with `push_error()` plus an `AcceptDialog`.

## Updating documentation

Keep this README in sync with the code: any change to features, menus, project structure, requirements, or usage must be reflected here in the same commit.
