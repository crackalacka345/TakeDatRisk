-- MM2_UpdateLog.lua
-- Newest entry first. Add a new { title = "...", changes = { ... } } block at the TOP for each update.
return {
    {
        title = "2026-11-21: New UI styles",
        changes = {
            "Added SETTINGS > UI STYLE: Classic / Glass / Sidebar",
            "Glass: translucent panels, soft gradient, pill tabs",
            "Sidebar: left icon rail with hover labels instead of the tab row",
        },
    },
    {
        title = "2026-11-21: Modules update",
        changes = {
            "Added MODULES tab: import .module files from a GitHub repo into any category",
            "Added MY MODULES tab with Remove and Clear All",
            "Imported modules appear as buttons in their category and toggle independently",
            "Added CHECK CODE security scanner (SAFE / WARNING / DANGEROUS report)",
            "Added trust confirmation popup before ADD imports anything",
            "Added Guide button in the MODULES tab",
            "Modules run through a controlled, sandboxed loader (MM2_ModuleLoader.lua)",
            "ESP, PLAYER and UI pages can now scroll when modules are added",
            "Added this Update Log button in SETTINGS",
        },
    },
}
