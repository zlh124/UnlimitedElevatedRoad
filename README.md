> **Status: unofficial continuation, published as a NEW mod (Paradox Mods id `164020`).**
>
> The original **ConfigurableElevatedRoad** (PDX ModId `77597`) by [Jimmyokok](https://github.com/Jimmyokok/UnlimitedElevatedRoad)
> is no longer maintained and stopped loading after a game update. This repository continues it, and the
> fixed build is published **as a separate mod with its own PDX ModId — not as an update to the original**,
> because `77597` belongs to the original author's account. Keep that in mind when installing:
>
> * This continuation is published under PDX Mods id **`164020`** ("Configurable Elevated Road (Continued)").
> * The first release is version **1.0.0** (the code is upstream 1.0.2 plus the compatibility fixes below).
> * **It cannot be installed alongside the original.** This is the same mod republished under a new id
>   (identical assembly name), so disable/unsubscribe the original `ConfigurableElevatedRoad` before
>   enabling this one.
> * Your settings carry over: same settings file name, same options layout, same feature set.
> * All credit for the original design and implementation stays with the original author.

If you want anarchy around elevated road construction,this mod suits you. With this mod, you are able to construction elevated roads/bridges/intersections at ease, free from the annoying pillars/steepness/length restrictions, and even build a roller coaster of road!

## Feature

* Configurable pillar interval (20m-800m).
* Optional no pillar construction mode.
* Configurable maximum edge section length (20m-800m).
* Optional no height limitation construction mode, that lifts the height restriction to 1000m.
* Optional no steepness limitation construction mode.
* One-click options to restore vanilla/mod default settings.
* The above settings all appear in the game setting menu and are recommended to be configured in-game. The changes you've made **immediately take effect** and persist in the configuration file.
	
## Important Notes

* This mod affects save games, as the road/bridges/tracks you've built are just there.
* This mod is currently BETA and still needs more testing. FEEDBACKS are most welcomed(via Github issues).
* Setting the maximum edge length to extreme values would possibly cause weird behaviors, e.g. extremely difficult to delete a piece of road. Please be cautious when playing with the maximum edge length.

## Technical

* Modified System: None

## Building

**Important:** the mod must be *recompiled* whenever the game updates. A build produced against an
older `Game.dll` is not forward compatible — method signatures in `Game.dll` / `Colossal.*.dll` change
between game versions, and an old assembly then fails to load with `MissingMethodException` (that is
exactly what happened to v1.0.2 on game 1.6).

### Local builds — no toolchain needed

The mod contains no `[BurstCompile]` code, so the toolchain's `ModPostProcessor.exe` (IL
post-processing + Burst) is not required to make it load. `tools/BuildLocal.ps1` compiles the sources
with Roslyn's `csc` against the *installed* game assemblies and copies the result into the game's
local `Mods` folder:

```powershell
pwsh -File tools/BuildLocal.ps1             # compile + install into Mods\ConfigurableElevatedRoad
pwsh -File tools/BuildLocal.ps1 -NoDeploy   # compile only (fast check after a game update)
```

Requirements: the game plus a .NET SDK (only for `csc.dll`). The script finds the game through
`CSII_INSTALLATIONPATH` / the Steam registry, so it works on non-default install locations.

> Both a local copy and a PDX subscription of the same mod cannot be active at the same time —
> disable the subscribed one in the mods list before testing a local build.

### Release builds / publishing — toolchain needed

Publishing goes through the official **Cities: Skylines II Modding Toolchain**: its `Mod.props` /
`Mod.targets` (imported through the `CSII_TOOLPATH` environment variable) resolve the game assemblies
and the `Publish` / `NewVersion` targets drive `ModPublisher`. Without it `dotnet build` fails with
`MSB4019: could not find "\Mod.props"`.

1. Launch the game with `-developerMode`.
2. Open **Options → Modding** and install every row until all show a green check mark
   (Unity + Unity Mod Project + .NET SDK; Node.js is only needed for UI mods). This also writes
   `Mod.props` / `Mod.targets` into `CSII_TOOLPATH`
   (typically `%USERPROFILE%\AppData\LocalLow\Colossal Order\Cities Skylines II\.cache\Modding`).
3. Build with `dotnet build -c Release` (net472 needs the .NET Framework 4.7.2 targeting pack or the
   `Microsoft.NETFramework.ReferenceAssemblies.net472` package), then publish through the
   `PublishNewVersion` profile.

### How this continuation was published (and how to update it)

The original mod (PDX ModId `77597`) is unmaintained, but its id belongs to the original author's
account — **a fork cannot be published as an update to it**. It therefore went up as a new mod:

1. ~~Get the original author's permission.~~ The upstream repository ships **no licence file**, which
   means "all rights reserved"; "the author stopped updating" is not by itself a licence to republish.
   Credit for the original work is kept in `LongDescription`, in this README, and in the mod page.
2. ~~Leave `<ModId Value="" />` empty for the first upload.~~ Done: the first upload created PDX Mods
   id **`164020`**, which is now recorded in `Properties/PublishConfiguration.xml`.
3. ~~Publish once (`PublishNewMod`).~~ Done, as version 1.0.0.

From now on:

```powershell
pwsh -File tools/Publish.ps1 -Mode NewVersion     # new version (bump ModVersion + rewrite ChangeLog first)
pwsh -File tools/Publish.ps1 -Mode UpdateConfig   # metadata only, no new version
```

`ModPublisher` needs a logged-in PDX session: start the game, log in, **quit the game** (it locks the
`Mods` folder), then run the command. Uploads also fail if `ShortDescription` exceeds 200 characters —
`tools/Publish.ps1` checks that before it calls the publisher.

## Changelog

### This continuation (published under its own PDX ModId)

- v1.0.0 — first release, a compatibility build of upstream 1.0.2
  - Rebuilt against the game 1.6 assemblies, so the mod loads again on current game versions
    (upstream 1.0.2 fails with `MissingMethodException: AssetDatabase.LoadSettings`).
  - Vanilla prefab section/sub-object data is only rewritten while "no pillar" mode is enabled;
    newer vanilla data (hidden/half-length section flags, waterway-crossing placements) is no longer
    overwritten by the reverse-engineered rebuild.
  - Added the waterway-crossing sub-object placements introduced by newer game versions.

### Upstream (original mod by Jimmyokok, ModId 77597)

- v1.0.2
  - Fixed a bug that leads to all sorts of weird behaviors when updating existing roads.

* v1.0.1
	* Fixed compatibility with ExtraLib and all mods that depend on it.

* v1.0.0
  * Mod exists for beta.