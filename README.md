# GOKZ Example SourceMod Template

This repository is a small, self-contained template for building SourceMod plugins that run on top of an existing [GOKZ](https://github.com/KZGlobalTeam/gokz) installation.

It mirrors the upstream GOKZ project in the places that matter for addon development:

- `addons/sourcemod/scripting` layout and multi-file plugin structure
- SourceMod 1.11 / CS:GO compile target
- `autoexecconfig`-based server config generation
- GOKZ option registration and options-menu integration
- GitHub Actions packaging similar to the upstream CI flow

## Included Example

The template ships one example addon: `gokz-example`.

It demonstrates how to:

- register a player option with GOKZ
- add that option into the GOKZ general options menu
- expose chat commands with `sm_example` and `sm_gokzexample`
- react to `GOKZ_OnTimerEnd_Post`
- generate `cfg/sourcemod/gokz/gokz-example.cfg`

The example plugin is intentionally small so it can be renamed and expanded into a real addon.

## Requirements

- CS:GO server
- SourceMod `1.11`
- Existing GOKZ installation providing `gokz-core`

This repository includes a minimal `include/gokz/core.inc` shim so the example plugin can compile in isolation. Runtime support still comes from the real GOKZ plugins on the server.

## Layout

- `addons/sourcemod/scripting/gokz-example.sp` — main plugin entrypoint
- `addons/sourcemod/scripting/gokz-example/` — modular feature files
- `addons/sourcemod/scripting/include/gokz/` — minimal version + GOKZ compile shim
- `addons/sourcemod/translations/gokz-example.phrases.txt` — example phrases
- `cfg/sourcemod/gokz/` — generated config target directory
- `.github/workflows/main.yml` — compile + package workflow

## Renaming The Template

To turn this into a real addon:

1. Rename `gokz-example.sp` and the `gokz-example/` folder to your plugin name.
2. Update:
   - plugin/library name in `AskPluginLoad2`
   - command names
   - translation filename
   - config filename in `AutoExecConfig_SetFile`
3. Expand the local `include/gokz/core.inc` shim only when your addon needs more of the upstream GOKZ API surface.

## Local Compile

One simple local compile flow is:

1. Download SourceMod `1.11`.
2. Copy this repository’s `addons` directory into the SourceMod package.
3. Run `spcomp` from `addons/sourcemod/scripting`:

```sh
./spcomp gokz-example.sp
```

If you prefer, the GitHub Actions workflow in `.github/workflows/main.yml` can be used as the reference build pipeline.

## Release Tags

Pushes to `main` or `master` automatically create a release tag before compiling:

- if no numeric SemVer tag exists, the first tag is `1.0.0`
- if any pushed commit subject matches Conventional Commit `feat:` or `feat(scope):`, the workflow bumps the minor version, e.g. `1.0.1` → `1.1.0`
- otherwise the workflow bumps the patch version, e.g. `1.0.0` → `1.0.1`
- pull requests compile with the short commit SHA instead of creating tags
- manually pushed tags compile with the tag name as the plugin version
- every non-PR release build publishes a GitHub Release with full and upgrade zip assets for `GOKZ_VERSION`

## Notes

- This template is for **GOKZ-related addons**, not standalone SourceMod plugins.
- `gokz-example` is the only shipped sample plugin.
- The generated config path is `cfg/sourcemod/gokz/gokz-example.cfg`.
