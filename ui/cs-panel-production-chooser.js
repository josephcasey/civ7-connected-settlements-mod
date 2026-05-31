// Connected Settlements — Production Chooser decorator
//
// Injects a "N Settlements Connected" line into the left-hand production /
// purchase panel (panel-production-chooser), alongside the town focus /
// specialization controls — a more convenient place to see the count while
// choosing a town's specialism than the separate City Details panel.
//
// Civ7 decorator contract (see core/ui/component-support.js doAttach/doDetach):
// every object returned by a Controls.decorate() factory MUST implement four
// lifecycle methods — beforeAttach, afterAttach, beforeDetach, afterDetach —
// because the framework calls them unconditionally. Omitting them throws
// "d.beforeDetach is not a function" on detach, which breaks view switching.
//
//   afterAttach()  -> panel is attached & rendered; inject + populate
//   beforeDetach() -> remove our element
// Per-city refresh (prev/next city buttons reuse the same panel instance) is
// handled by wrapping the prototype's updateCityName(), which the panel calls
// from its cityID setter on every city change.
//
// `Controls`, `Cities`, `UI`, and `Locale` are globals in the Civ7 UI sandbox.

import { getConnectedSettlements } from "/jc-connected-settlements/ui/cs-connections-model.js";

const CS_HEADER_CLASS = "cs-connections-header";

class csProductionChooserConnections {
    constructor(component) {
        this.component = component;
        component.csComponent = this;
        this.patchPrototype(component);
    }

    // Wrap updateCityName() once on the shared prototype so the count refreshes
    // whenever the panel switches city without a full detach/attach.
    patchPrototype(component) {
        const proto = Object.getPrototypeOf(component);
        if (csProductionChooserConnections.patched === proto) return;
        csProductionChooserConnections.patched = proto;

        const baseUpdateCityName = proto.updateCityName;
        proto.updateCityName = function (city) {
            const rv = baseUpdateCityName.apply(this, arguments);
            try {
                this.csComponent?.updateCount(city);
            } catch (e) {
                console.error("cs-connections: updateCount failed", e);
            }
            return rv;
        };
    }

    // --- decorator lifecycle (all four required by the framework) ---
    beforeAttach() {}

    afterAttach() {
        // The panel has rendered; inject our element and populate it once.
        this.injectHeader();
        const city = this.getCurrentCity();
        if (city) this.updateCount(city);
    }

    beforeDetach() {
        this.headerElement?.remove();
        this.headerElement = null;
    }

    afterDetach() {}

    // --- helpers ---
    getCurrentCity() {
        const id = UI.Player?.getHeadSelectedCity?.();
        return id ? Cities.get(id) : null;
    }

    // Slot a header element into the panel frame, mirroring how the base game
    // appends its own cityStatusContainerElement (a data-slot="header" child).
    injectHeader() {
        const frame = this.component?.frame;
        if (!frame) return;
        if (this.headerElement?.isConnected) return;

        const el = document.createElement("div");
        el.classList.add(
            CS_HEADER_CLASS,
            "font-body",
            "text-sm",
            "text-center",
            "tracking-100",
            "uppercase",
            "mb-1"
        );
        el.dataset.slot = "header";
        this.headerElement = el;
        frame.appendChild(el);
    }

    updateCount(city) {
        if (!this.headerElement?.isConnected) this.injectHeader();
        if (!this.headerElement) return;
        const data = getConnectedSettlements(city);
        this.headerElement.textContent = Locale.compose(
            "LOC_CS_CONNECTED_COUNT",
            data.total
        );
    }
}

Controls.decorate(
    "panel-production-chooser",
    (component) => new csProductionChooserConnections(component)
);
