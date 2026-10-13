// Small line icons that stand in for the Blizzard icon textures used in the sidebar.
// (Blizzard icon art can't be shipped in the repo, so the mockups use neutral glyphs.)
window.MLZ_ICONS = {
    overview:   '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>',
    layout:     '<rect x="3" y="4" width="18" height="16" rx="1"/><path d="M3 15h18M9 15v5M15 15v5"/>',
    nameplates: '<rect x="4" y="9" width="16" height="5" rx="1"/><path d="M8 6h8"/><path d="M4 17h10"/>',
    healer:     '<path d="M12 5v14M5 12h14"/>',
    fade:       '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    buttons:    '<rect x="3" y="7" width="5" height="10"/><rect x="9.5" y="7" width="5" height="10"/><rect x="16" y="7" width="5" height="10"/>',
    qol:        '<circle cx="12" cy="12" r="8"/><path d="M12 8v8M9.5 10.5h4a1.5 1.5 0 010 3h-3a1.5 1.5 0 000 3h4"/>',
    addons:     '<path d="M5 8h14l-1 12H6L5 8z"/><path d="M9 8V6a3 3 0 016 0v2"/>',
    profiles:   '<path d="M6 3h9l4 4v14H6z"/><path d="M9 12h7M9 16h7"/>',
    about:      '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 114 2c-1 .6-1.5 1.2-1.5 2.5M12 17h.01"/>',
};

window.MLZ_GEAR = '<svg viewBox="0 0 24 24" fill="none" stroke="#d8dce4" stroke-width="2.2"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/></svg>';

window.mlzIcon = function (name, color) {
    return '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="' + (color || "currentColor") +
        '" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + (window.MLZ_ICONS[name] || "") + "</svg>";
};

// Fills every [data-gear] with the title bar gear icon and every [data-icon] with its glyph
document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll("[data-gear]").forEach(function (el) { el.innerHTML = window.MLZ_GEAR; });
    document.querySelectorAll("[data-icon]").forEach(function (el) {
        el.innerHTML = window.mlzIcon(el.getAttribute("data-icon"));
    });
});
