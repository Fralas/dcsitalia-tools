# DCORE Zone Link Editor

A **DCS World Mission Editor** extension for defining bidirectional links between trigger zones. Part of the [DCORE](https://github.com/) mission scripting toolkit.

Define zone adjacency graphs visually, persist them per mission, export to Lua config files used by runtime tools such as **DZONE_TEST** and **DMAP**.

## What it does

| Feature | Description |
|---------|-------------|
| **Visual linking** | Click zones on the ME map to create bidirectional links |
| **Live overlay** | Optional white link lines on the ME map (UI overlay, not Draw objects) |
| **Per-mission storage** | Graph saved as JSON under Saved Games |
| **Lua export** | Replaces only the `local confini = { ... }` block in your config file |
| **Disk-first reload** | Graph is re-read from JSON before every action to avoid stale state |

Links are **not** written into the `.miz`. The mission file stays clean; adjacency data lives in Saved Games JSON and your chosen Lua config.

## How it works

1. **Create links** in the ME — each click adds a symmetric edge and writes JSON immediately.
2. **Save** exports the graph to your configured Lua file (`confini` table).
3. **In mission**, load `DZONE_TEST.lua` (or DMAP) to draw circles and lines on the F10 map and validate the graph.

### Data model

The graph uses a `confini` table (same format as DMAP):

```lua
local confini = {
  ["zone_00"] = {"zone_01", "zone_10"},
  ["zone_01"] = {"zone_00", "zone_02"},
}
```

Each key is a zone name; values are lists of adjacent zone names. Links are always stored **bidirectionally**.

## Requirements

- DCS World with Mission Editor
- Write access to `<DCS>\MissionEditor\MissionEditor.lua` (Administrator may be required if DCS is under Program Files)
- **Full DCS restart** after install or uninstall (ME Lua loads once at startup)

## Installation

From this directory, run this powershell command and specify your custom DCS path:
.\install.ps1 -DcsPath "F:\DCS World OpenBeta"

The installer:

1. Copies modules to `<DCS>\MissionEditor\modules\dcore_zone_linker\`
2. Patches `MissionEditor.lua` with `require('dcore_zone_linker.init')` (backup: `.dcore-zone-linker.bak`)

## Uninstall
Simply run
.\uninstall.ps1

## Usage

1. Restart DCS and open the Mission Editor.
2. Open **DCORE Tools → Zone Link Editor**.
3. Click **Create link**.
4. Click the **base zone** on the map (nearest trigger zone to the click).
5. Click **target zones** to link (each click adds a bidirectional edge).
6. Click **Save** — writes JSON + exports `confini` to your config file.
7. **Show links** / **Hide links** — toggle the ME map overlay.
8. **Config** — paths, zone filter, and other options.

### While linking

- **Right-drag** — pan the map (unchanged ME behaviour).
- **Cancel** (same button as Create link) — exit link mode.
- The panel stays visible while you click the map.

### Config dialog

Open via the **Config** button or **DCORE Tools → Zone Link Editor - Config**.

| Setting | Description |
|---------|-------------|
| **Saved Games** | DCS Saved Games folder for JSON graphs. Empty = auto (`lfs.writedir`) |
| **Install DCS** | DCS installation directory (e.g. `F:\DCS World OpenBeta`) |
| **Confini export** | Target `.lua` file for the `confini` block |
| **Zone prefix** | Filter trigger zones on the map (default `zone_`) |
| **All zones** | Ignore prefix filter |
| **Overlay on start** | Enable link overlay when opening the panel |

Settings file:

```text
<Saved Games>/dcore-tools/zone-linker/settings.lua
```

Graph JSON per mission:

```text
<Saved Games>/dcore-tools/zone-linker/graphs/<mission_name>.json
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| **DCORE Tools** menu missing | Verify patch in `MissionEditor.lua`; restart DCS completely |
| Install permission error | Run PowerShell as Administrator |
| Patch lost after DCS update | Re-run `install.ps1` |
| DCS won't start | Restore `MissionEditor.lua` from `.dcore-zone-linker.bak`; re-run `install.ps1` |
| Config export failed | Ensure `local confini = {` exists in the target Lua file |
| No zones in list | Enable **All zones** in Config or check zone names / prefix |
| Stale links after editing JSON | Re-open the panel — graph reloads from disk on every action |

Logs: `<Saved Games>/Logs/dcs.log` — search for `dcore.zone_linker`

## Project structure

```text
DZONE_LINK_EDITOR/
├── install.ps1
├── uninstall.ps1
├── README.md
└── me-mod/lua/dcore_zone_linker/
    ├── init.lua              # Bootstrap
    ├── menu.lua              # DCORE Tools menubar
    ├── zone_link_window.lua  # Main editor panel
    ├── config_window.lua     # Settings dialog
    ├── map_pick.lua          # Map click → nearest zone
    ├── map_overlay.lua       # ME link lines overlay
    ├── zone_list.lua         # Trigger zone enumeration
    ├── graph.lua             # Bidirectional graph model
    ├── persistence.lua       # JSON per mission
    ├── config_export.lua     # Surgical confini export
    ├── settings.lua          # Persistent settings
    ├── selection.lua         # ME selection helpers
    └── util.lua              # Logging
```

## Related tools

| Tool | Role |
|------|------|
| **DZONE_TEST** | Standalone F10 validator; reads `DZONE_TEST_Config.lua` |
| **DMAP** | Full zone map system; uses the same `confini` format |

## License
Part of the DCORE project. Use and modify this software in accordance with your repository license. Commercial use is strictly prohibited, including use in projects, services, or products that generate revenue, profit, or other forms of monetary compensation.
