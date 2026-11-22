-- MM2_UpdateLog.lua
-- Fallback log (used when GitHub commits can't be read). Newest entry first.
-- Version rule: big update = +0.1, small update = +0.01.
return {
    {
        title = "v3.31 (big): UI Styles",
        changes = {
            "Added SETTINGS > UI STYLE: Classic / Glass / Sidebar",
            "Glass: translucent panels, soft gradient, pill tabs, rounded cards",
            "Sidebar: left icon rail with hover labels instead of the tab row",
            "Chosen style is saved and re-applied on start",
        },
    },
    {
        title = "v3.21 (small): Update Log + loader split",
        changes = {
            "Added Update Log button in SETTINGS (reads recent GitHub commits, checks every 2 minutes, shows NEW)",
            "Module loader and scanner moved to MM2_ModuleLoader.lua to keep this script smaller",
        },
    },
    {
        title = "v3.20: Modules system",
        changes = {
            "Added MODULES tab: import .module files from a GitHub repo into any category",
            "Added MY MODULES tab with Remove and Clear All",
            "Imported modules appear as buttons in their category and toggle independently",
            "Added CHECK CODE security scanner (SAFE / WARNING / DANGEROUS report)",
            "Added trust confirmation popup before ADD imports anything",
            "Modules run in a controlled, sandboxed loader",
            "Added Guide button in the MODULES tab",
            "ESP, PLAYER and UI pages can scroll when modules are added",
        },
    },
}
