-- name: NEXO Mashup A
-- description: NEXO Mashup Lab prototype. A6.1: visible growth verification after working Goomba absorption.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "A6.1 CRECIMIENTO VISIBLE"
local RESET_HINT = "DPAD ABAJO: reiniciar  |  B: golpe fuerte"

-- The Spiny Ball model has its own internal GEO scale, so the old 1.15 -> 1.33
-- change was too subtle. This gate deliberately exaggerates growth.
local BASE_SCALE = 1.80
local SCALE_PER_GOOMBA = 0.55
local MAX_SCALE = 6.00
local GROWTH_SPEED = 0.075

local BASE_WALL_RADIUS = 70.0
local BASE_HITBOX_RADIUS = 125
local BASE_HITBOX_HEIGHT = 125

local absorbed_count = 0
local target_scale = BASE_SCALE
local visual_scale = BASE_SCALE
local hit_flash = 0
local absorb_flash = 0

local function reset_progress()
    absorbed_count = 0
    target_scale = BASE_SCALE
    visual_scale = BASE_SCALE
    absorb_flash = 0
    hit_flash = 0
end

local function update_target_scale()
    target_scale = math.min(BASE_SCALE + absorbed_count * SCALE_PER_GOOMBA, MAX_SCALE)
end

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function apply_visual_scale(obj)
    -- Explicit per-axis scale writes to header.gfx.scale through the engine helper.
    obj_scale_xyz(obj, visual_scale, visual_scale, visual_scale)
end

local function update_collision_scale(obj)
    local ratio = visual_scale / BASE_SCALE
    obj.oWallHitboxRadius = BASE_WALL_RADIUS * ratio
    obj.hitboxRadius = BASE_HITBOX_RADIUS * ratio
    obj.hitboxHeight = BASE_HITBOX_HEIGHT * ratio
end

local function bhv_nexo_ball_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 35

    apply_visual_scale(obj)

    obj.oGravity      = 2.50
    obj.oBounciness   = -0.25
    obj.oDragStrength = 0.00
    obj.oFriction     = 0.955
    obj.oBuoyancy     = -2.00

    update_collision_scale(obj)

    network_init_object(obj, true, nil)
end

local function absorb_nearby_goombas(obj)
    local ratio = visual_scale / BASE_SCALE
    local absorb_radius = 105 + 55 * ratio

    local goomba = obj_get_first_with_behavior_id(id_bhvGoomba)
    local safety = 0

    while goomba ~= nil and safety < 256 do
        safety = safety + 1
        local next_goomba = obj_get_next_with_same_behavior_id(goomba)

        if dist_between_objects(obj, goomba) <= absorb_radius then
            obj_mark_for_deletion(goomba)

            absorbed_count = absorbed_count + 1
            update_target_scale()

            absorb_flash = 45
            obj.oVelY = math.max(obj.oVelY, 5)

            cur_obj_play_sound_2(SOUND_GENERAL_COIN)

            print(
                "[NEXO] Goomba absorbed. Total="
                .. tostring(absorbed_count)
                .. " targetScale="
                .. tostring(target_scale)
            )
        end

        goomba = next_goomba
    end
end

local function bhv_nexo_ball_loop(obj)
    -- Smooth but obvious growth. We intentionally animate toward the target so
    -- the player can SEE the absorption effect rather than comparing snapshots.
    if visual_scale < target_scale then
        visual_scale = math.min(visual_scale + GROWTH_SPEED, target_scale)
    elseif visual_scale > target_scale then
        visual_scale = math.max(visual_scale - GROWTH_SPEED, target_scale)
    end

    apply_visual_scale(obj)
    update_collision_scale(obj)

    absorb_nearby_goombas(obj)

    local m = nearest_mario_state_to_object(obj)
    if m == nil or m.marioObj == nil then
        object_step_without_floor_orient()
        return
    end

    local player = m.marioObj
    local distance_to_player = dist_between_objects(obj, player)
    local angle_to_player = obj_angle_to_object(obj, player)
    local local_player_touch = false

    local ratio = visual_scale / BASE_SCALE

    -- Larger starting radius makes the prototype substantially easier to control.
    local push_radius = 130 + 50 * ratio
    local strong_hit_radius = push_radius + 65

    local strong_hit = ((m.controller.buttonPressed & B_BUTTON) ~= 0)
                       and distance_to_player < strong_hit_radius

    if strong_hit then
        obj.oMoveAngleYaw = angle_to_player + 0x8000

        local strong_speed = math.max(46, 62 - absorbed_count * 1.5)
        obj.oForwardVel = math.max(obj.oForwardVel, strong_speed)
        obj.oVelY = math.max(obj.oVelY, 10)

        if m.playerIndex == 0 then
            hit_flash = 24
            local_player_touch = true
        end

    elseif distance_to_player < push_radius then
        local xdiff = player.oPosX - obj.oPosX
        local zdiff = player.oPosZ - obj.oPosZ

        if distance_to_player > 1 then
            -- Gentle separation so Mario does not get swallowed by the growing hitbox.
            obj.oPosX = obj.oPosX - (push_radius - distance_to_player) / push_radius * xdiff * 0.72
            obj.oPosZ = obj.oPosZ - (push_radius - distance_to_player) / push_radius * zdiff * 0.72
        end

        obj.oMoveAngleYaw = angle_to_player + 0x8000

        local mario_speed = math.abs(m.forwardVel)
        local mass_factor = 1 + absorbed_count * 0.12
        local push = (2.0 + math.min(mario_speed * 0.08, 4.5)) / mass_factor

        -- Lower passive top speed improves steering/control.
        obj.oForwardVel = math.min(obj.oForwardVel + push, 25)

        if m.playerIndex == 0 then
            local_player_touch = true
        end
    end

    local step_rc = object_step_without_floor_orient()

    if step_rc == 1 then
        cur_obj_play_sound_2(SOUND_GENERAL_BOX_LANDING_2)
    elseif (step_rc & 1) ~= 0 and obj.oForwardVel > 18.0 then
        cur_obj_play_sound_2(SOUND_ENV_SLIDING)
    end

    local floor = cur_obj_update_floor_height_and_get_floor()
    if floor ~= nil then
        obj_check_floor_death(step_rc, floor)
    end

    obj.oFaceAngleYaw = obj.oMoveAngleYaw
    obj.oFaceAnglePitch = obj.oFaceAnglePitch + obj.oForwardVel * 95
    obj.oFaceAngleRoll = obj.oFaceAngleRoll + obj.oForwardVel * 28

    if local_player_touch then
        network_send_object(obj, false)
    end
end

id_bhvNexoBall = hook_behavior(
    nil,
    OBJ_LIST_DEFAULT,
    true,
    bhv_nexo_ball_init,
    bhv_nexo_ball_loop
)

local function spawn_ball_for_mario(m)
    local existing = get_ball()
    if existing ~= nil then
        obj_mark_for_deletion(existing)
    end

    local distance = 300
    local x = m.pos.x + sins(m.faceAngle.y) * distance
    local y = m.pos.y + 110
    local z = m.pos.z + coss(m.faceAngle.y) * distance

    spawn_sync_object(
        id_bhvNexoBall,
        E_MODEL_SPINY_BALL,
        x, y, z,
        nil
    )

    print("[NEXO] A6.1 ball spawned")
end

local function mario_update(m)
    if m.playerIndex ~= 0 then
        return
    end

    if hit_flash > 0 then
        hit_flash = hit_flash - 1
    end

    if absorb_flash > 0 then
        absorb_flash = absorb_flash - 1
    end

    if get_ball() == nil then
        spawn_ball_for_mario(m)
        return
    end

    if (m.controller.buttonPressed & D_JPAD) ~= 0 then
        reset_progress()
        spawn_ball_for_mario(m)
    end
end

local function on_level_init()
    reset_progress()
end

local function on_hud_render()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)

    local x = 28
    local y = 28
    local title_scale = 0.54
    local status_scale = 0.39
    local info_scale = 0.25

    local ball = get_ball()
    local speed_text = "VEL: --"
    local gfx_text = "GFX: --"

    if ball ~= nil then
        speed_text = "VEL: " .. tostring(math.floor(math.abs(ball.oForwardVel)))
        gfx_text = string.format("GFX: %.2f", ball.header.gfx.scale.x)
    end

    local target_text = string.format("OBJ: %.2f", target_scale)
    local visual_text = string.format("VIS: %.2f", visual_scale)
    local count_text = "GOOMBAS: " .. tostring(absorbed_count)

    local width = 485
    local height = 151

    djui_hud_set_color(0, 0, 0, 175)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 29, status_scale)

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(
        count_text .. " | " .. target_text .. " | " .. visual_text,
        x, y + 53, info_scale
    )

    djui_hud_set_color(170, 220, 255, 255)
    djui_hud_print_text(gfx_text .. " | " .. speed_text, x, y + 71, info_scale)

    if absorb_flash > 0 then
        djui_hud_set_color(120, 255, 120, 255)
        djui_hud_print_text("CRECIENDO! GOOMBA +1", x, y + 91, 0.32)
    elseif hit_flash > 0 then
        djui_hud_set_color(255, 120, 80, 255)
        djui_hud_print_text("GOLPE FUERTE!", x, y + 91, 0.32)
    else
        djui_hud_set_color(220, 220, 220, 255)
        djui_hud_print_text(RESET_HINT, x, y + 93, info_scale)
    end

    djui_hud_set_color(180, 180, 180, 255)
    djui_hud_print_text("Prueba clave: VIS y GFX deben subir al absorber", x, y + 116, 0.23)
    djui_hud_print_text("Modelo con puntas = provisional", x, y + 133, 0.23)
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] A4-A5 PASS; A6.1 visible growth validation active")
