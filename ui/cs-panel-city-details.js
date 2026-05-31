// Connected Settlements — City Details panel decorator (ALTERNATE placement)
//
// Injects a "Connected Settlements" section (count + clickable list of names)
// into the vanilla City Details panel (the right-hand panel). This is an
// alternate to ui/cs-panel-production-chooser.js, which puts the same count in
// the left-hand production/purchase panel. The modinfo loads only one of them;
// swap the <Item> in connected-settlements.modinfo to use this placement.
//
// Technique (verified against City Hall, bszonye/civ7-city-hall v2.6.9):
//   Controls.decorate("panel-city-details", factory)
//       Registers a decorator the engine instantiates per panel-city-details
//       component. We wrap the component's render() so our content is rebuilt
//       whenever the panel re-renders.
//
// Civ7 decorator contract (see core/ui/component-support.js): every decorator
// MUST implement beforeAttach / afterAttach / beforeDetach / afterDetach — the
// framework calls them unconditionally, so omitting them throws
// "d.beforeDetach is not a function" on detach and breaks view switching.
//
// `Controls`, `Cities`, `UI`, and `Locale` are globals in the Civ7 UI sandbox.

import { getConnectedSettlements } from "/jc-connected-settlements/ui/cs-connections-model.js";

const CS_SECTION_CLASS = "cs-connections-section";

class csCityDetailsConnections {
    constructor(component) {
        this.component = component;
        // Back-reference so the wrapped prototype render() can reach us.
        component.csComponent = this;
        this.onRowActivate = this.onRowActivate.bind(this);
        this.patchRender(component);
    }

    // Wrap the shared panel prototype's render() exactly once.
    patchRender(component) {
        const proto = Object.getPrototypeOf(component);
        if (csCityDetailsConnections.patched === proto) return;
        csCityDetailsConnections.patched = proto;

        const baseRender = proto.render;
        proto.render = function (...args) {
            const rv = baseRender.apply(this, args);
            // `this` is the panel component; csComponent is our decorator.
            try {
                this.csComponent?.afterRender();
            } catch (e) {
                console.error("cs-connections: afterRender failed", e);
            }
            return rv;
        };
    }

    // --- decorator lifecycle (all four required by the framework) ---
    beforeAttach() {}
    afterAttach() {}
    beforeDetach() {}
    afterDetach() {}

    getCurrentCity() {
        const id = UI.Player?.getHeadSelectedCity?.();
        return id ? Cities.get(id) : null;
    }

    afterRender() {
        const root = this.component?.Root;
        if (!root) return;

        // Remove any previous render so re-renders don't stack duplicates.
        root.querySelector(`.${CS_SECTION_CLASS}`)?.remove();

        const data = getConnectedSettlements(this.getCurrentCity());

        // Always render — a count of 0 (e.g. a freshly founded city) is a valid
        // state, and showing "0 Settlements Connected" makes it obvious the mod
        // is active rather than silently broken.

        // Append inside the growth tab's scrollable so the section is visible
        // within the panel rather than spilling off the bottom of the screen.
        // Falls back to root if the expected structure isn't found.
        const growthSlot = root.querySelector("#city-details-tab-growth");
        const scrollable = growthSlot?.querySelector("fxs-scrollable") ?? root;

        const section = document.createElement("div");
        section.classList.add(CS_SECTION_CLASS, "flex", "flex-col", "px-3", "py-2");

        // Header: "N Settlements Connected". Note: this is a fully composed
        // string (parameter already substituted), so it goes in textContent —
        // NOT data-l10n-id, which expects a raw localization KEY.
        const header = document.createElement("div");
        header.classList.add("font-title", "text-sm", "uppercase", "tracking-wide");
        header.textContent = Locale.compose("LOC_CS_CONNECTED_COUNT", data.total);
        section.appendChild(header);

        // List: one clickable row per connected settlement.
        for (const conn of data.all) {
            const row = document.createElement("fxs-activatable");
            row.classList.add("cs-connection-row", "flex", "items-center", "py-0\\.5");
            row.setAttribute("tabindex", "-1");
            row.setAttribute("cs-city-id", JSON.stringify(conn.id));
            row.addEventListener("action-activate", this.onRowActivate);

            const name = document.createElement("div");
            name.classList.add("text-base", "text-left", "truncate");
            name.setAttribute("data-l10n-id", conn.name);
            row.appendChild(name);

            section.appendChild(row);
        }

        scrollable.appendChild(section);
    }

    // Clicking a settlement selects it (same behaviour as City Hall's links).
    onRowActivate(event) {
        const raw = event.target?.getAttribute("cs-city-id");
        if (raw) UI.Player.selectCity(JSON.parse(raw));
    }
}

Controls.decorate(
    "panel-city-details",
    (component) => new csCityDetailsConnections(component)
);
