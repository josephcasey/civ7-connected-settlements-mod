// Connected Settlements — data model
//
// Computes the set of settlements that are connected to a given settlement
// (i.e. share the same trade network branch reachable from this city).
//
// The core API used here is verified against the base game and the City Hall
// mod (bszonye/civ7-city-hall, v2.6.9, current as of game patch 1.4.0):
//
//   city.getConnectedCities() -> Array<ComponentID>
//       The list of settlements connected to `city`. IDs only.
//   Cities.get(id)            -> City object (or null if stale/broken)
//       Has: .id, .name (a localization key), .isTown (bool),
//            .Growth?.growthType (compare against GrowthTypes.EXPAND).
//
// `Cities`, `Locale`, and `GrowthTypes` are globals in the Civ7 UI sandbox.

/**
 * @typedef {Object} ConnectedSettlements
 * @property {number} total            Count of connected settlements.
 * @property {object[]} all            All connected settlement objects, name-sorted.
 * @property {object[]} cities         Connected settlements that are cities.
 * @property {object[]} towns          Connected settlements that are towns.
 */

/**
 * Resolve the connected-settlement data for a city.
 * Pure-ish: only reads game state, never mutates it.
 *
 * @param {object|null} city  A City object (e.g. from Cities.get).
 * @returns {ConnectedSettlements}
 */
export function getConnectedSettlements(city) {
    const empty = { total: 0, all: [], cities: [], towns: [] };
    if (!city || typeof city.getConnectedCities !== "function") return empty;

    const ids = city.getConnectedCities() ?? [];
    // Resolve IDs to objects and drop any that no longer exist (stale links).
    const all = ids
        .map((id) => Cities.get(id))
        .filter((s) => s != null)
        .sort((a, b) =>
            Locale.compose(a.name).localeCompare(Locale.compose(b.name))
        );

    const cities = all.filter((s) => !s.isTown);
    const towns = all.filter((s) => s.isTown);
    return { total: all.length, all, cities, towns };
}
