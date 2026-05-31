# Connected Settlements (Civ VII mod)

A small UI mod for Sid Meier's Civilization VII. It shows **how many settlements
are connected** to the selected city or town — plus a clickable list of their
names — inside the **City Details** panel.

> Status: **scaffold / 0.1.0**, targeting game patch **1.4.0 (Test of Time)**.
> The data layer and wiring are in place; the in-panel placement and styling
> still need to be verified in a running game (see *Verifying in-game* below).

## What it does

- Reads the connected-settlement list for the selected settlement.
- Renders an `"N Settlements Connected"` header followed by one row per
  connected settlement; clicking a row selects that settlement.

## How it works

| File | Role |
|------|------|
| `connected-settlements.modinfo` | Mod manifest. Registers the UI scripts and text under a `scope="game"` action group (LoadOrder 1000, so it patches the base UI after it loads). |
| `ui/cs-connections-model.js` | Pure data layer. `getConnectedSettlements(city)` resolves `city.getConnectedCities()` IDs into name-sorted city/town objects with a `total` count. |
| `ui/cs-panel-city-details.js` | UI layer. Uses `Controls.decorate("panel-city-details", …)` to wrap the vanilla panel's `render()` and append our section. |
| `text/en_us/InGameText.xml` | In-game strings (the count header). |
| `text/en_us/ModInfoText.xml` | Mod name/description shown in the mods list. |

### Verified game APIs

These were confirmed against the base game and the **City Hall** mod
(`bszonye/civ7-city-hall` v2.6.9, current on patch 1.4.0), which implements the
same feature inside a larger overhaul:

- `city.getConnectedCities()` → array of settlement `ComponentID`s.
- `Cities.get(id)` → city object (`.id`, `.name`, `.isTown`, `.Growth?.growthType`).
- `Controls.decorate(panelName, factory)` → the supported way to extend an
  existing UI panel without replacing it.
- `UI.Player.selectCity(id)` → select a settlement (used for clickable rows).

## 1.4.0 (Test of Time) notes

Patch 1.4.0 reworked parts of the UI framework and broke many existing mods
until updated. This scaffold accounts for that by:

- Using the current `modinfo` schema (`<Mod … xmlns="ModInfo">` with
  `ActionGroups`/`UIScripts`), matching mods known to load on 1.4.0.
- Extending the panel via `Controls.decorate` rather than overwriting base
  files, so future base-UI tweaks are less likely to hard-break it.
- Keeping the data layer (`cs-connections-model.js`) free of any DOM/framework
  coupling, so only the thin panel layer needs revisiting if the UI shifts.

## Verifying in-game

1. Copy/symlink this folder into the Civ VII `Mods` directory.
2. Enable **Connected Settlements** in the in-game mods menu, start/load a game.
3. Select a city or town and open **City Details** — the section should appear.

Things to confirm and likely tune:
- `getCurrentCity()` uses `UI.Player.getHeadSelectedCity()`. If the panel
  exposes its own city handle, prefer that.
- Placement: we `appendChild` to the panel root. The exact spot/styling may
  need adjusting once seen on screen.

## Preview image

`assets/preview.png` is the Workshop/CivFanatics preview graphic.

- **512×512, square, PNG, ~84 KB** — matches the Steam Workshop preview spec
  (square, recommended ~512×512, under the 1 MB limit; PNG/JPG accepted).
- Regenerate with `python3 tools/make_preview.py` (Pillow). It renders at 2×
  and downsamples for crisp edges.

## Credits

Approach studied from **City Hall** by *beezany* —
<https://github.com/bszonye/civ7-city-hall> /
<https://forums.civfanatics.com/resources/city-hall.31946/>.
This mod is an independent, minimal implementation, not derived code.
