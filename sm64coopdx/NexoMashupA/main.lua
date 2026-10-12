-- name: NEXO Mashup A
-- description: NEXO Mashup Lab prototype. Gate A0 verifies the Lua mod pipeline.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "GATE A0 PASS"

local function on_hud_render()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)

    local x = 28
    local y = 28
    local title_scale = 0.65
    local status_scale = 0.48

    local title_width = djui_hud_measure_text(TITLE) * title_scale
    local status_width = djui_hud_measure_text(STATUS) * status_scale
    local width = math.max(title_width, status_width) + 28
    local height = 72

    -- translucent diagnostic panel
    djui_hud_set_color(0, 0, 0, 170)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    -- pulse the PASS indicator so we know the hook is actively running
    local pulse = math.floor((math.sin(get_global_timer() / 12) * 0.5 + 0.5) * 80)
    djui_hud_set_color(120 + pulse, 255, 140 + math.floor(pulse / 2), 255)
    djui_hud_print_text(STATUS, x, y + 34, status_scale)
end

hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] Mashup A loaded — Gate A0 active")
