-- name: NEXO Mashup A
-- description: NEXO Mashup Lab prototype. A1-A3.1: real 3D test model, physics and differentiated push/hit.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "A1-A3.1 3D / FISICA"
local RESET_HINT = "DPAD ABAJO: reiniciar  |  B: golpe fuerte"

local hit_flash = 0

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function bhv_nexo_ball_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 35

    -- Temporary TRUE 3D model. We deliberately avoid E_MODEL_BOWLING_BALL:
    -- its vanilla display list reads visually like a flat disc.
    cur_obj_scale(1.15)

    -- Physics adapted from the official SM64CoopDX custom ball example.
    obj.oWallHitboxRadius = 55.0
    obj.oGravity          = 2.50
    obj.oBounciness       = -0.35
    obj.oDragStrength     = 0.00
    obj.oFriction         = 0.97
    obj.oBuoyancy         = -2.00

    obj.hitboxRadius = 95
    obj.hitboxHeight = 95

    network_init_object(obj, true, nil)
end

local function bhv_nexo_ball_loop(obj)
    local m = nearest_mario_state_to_object(obj)
    if m == nil or m.marioObj == nil then
        object_step_without_floor_orient()
        return
    end

    local player = m.marioObj
    local distance_to_player = dist_between_objects(obj, player)
    local angle_to_player = obj_angle_to_object(obj, player)
    local local_player_touch = false

    -- Explicit B press is used as the test oracle for a strong hit.
    -- This is intentionally distinct from passive body pushing.
    local strong_hit = ((m.controller.buttonPressed & B_BUTTON) ~= 0)
                       and distance_to_player < 185

    if strong_hit then
        obj.oMoveAngleYaw = angle_to_player + 0x8000
        obj.oForwardVel = math.max(obj.oForwardVel, 78)
        obj.oVelY = math.max(obj.oVelY, 20)

        if m.playerIndex == 0 then
            hit_flash = 24
            local_player_touch = true
        end
    elseif distance_to_player < 115 then
        -- Normal body push: deliberately much weaker than B.
        local xdiff = player.oPosX - obj.oPosX
        local zdiff = player.oPosZ - obj.oPosZ

        if distance_to_player > 1 then
            obj.oPosX = obj.oPosX - (115 - distance_to_player) / 115 * xdiff
            obj.oPosZ = obj.oPosZ - (115 - distance_to_player) / 115 * zdiff
        end

        obj.oMoveAngleYaw = angle_to_player + 0x8000

        local mario_speed = math.abs(m.forwardVel)
        local push = 2.5 + math.min(mario_speed * 0.10, 5.5)
        obj.oForwardVel = math.min(obj.oForwardVel + push, 34)

        if m.playerIndex == 0 then
            local_player_touch = true
        end
    end

    local step_rc = object_step_without_floor_orient()

    if step_rc == 1 then
        cur_obj_play_sound_2(SOUND_GENERAL_BOX_LANDING_2)
    elseif (step_rc & 1) ~= 0 and obj.oForwardVel > 20.0 then
        cur_obj_play_sound_2(SOUND_ENV_SLIDING)
    end

    local floor = cur_obj_update_floor_height_and_get_floor()
    if floor ~= nil then
        obj_check_floor_death(step_rc, floor)
    end

    -- Visible roll of the TRUE 3D temporary model.
    obj.oFaceAngleYaw = obj.oMoveAngleYaw
    obj.oFaceAnglePitch = obj.oFaceAnglePitch + obj.oForwardVel * 105
    obj.oFaceAngleRoll = obj.oFaceAngleRoll + obj.oForwardVel * 35

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

    local distance = 260
    local x = m.pos.x + sins(m.faceAngle.y) * distance
    local y = m.pos.y + 90
    local z = m.pos.z + coss(m.faceAngle.y) * distance

    spawn_sync_object(
        id_bhvNexoBall,
        E_MODEL_SPINY_BALL,
        x, y, z,
        nil
    )

    print("[NEXO] A1-A3.1 3D ball spawned")
end

local function mario_update(m)
    if m.playerIndex ~= 0 then
        return
    end

    if hit_flash > 0 then
        hit_flash = hit_flash - 1
    end

    if get_ball() == nil then
        spawn_ball_for_mario(m)
        return
    end

    if (m.controller.buttonPressed & D_JPAD) ~= 0 then
        spawn_ball_for_mario(m)
    end
end

local function on_hud_render()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)

    local x = 28
    local y = 28
    local title_scale = 0.58
    local status_scale = 0.42
    local info_scale = 0.28

    local ball = get_ball()
    local ball_status = "BOLA 3D: ACTIVA"
    local speed_text = "VEL: --"

    if ball == nil then
        ball_status = "BOLA 3D: REAPARECIENDO"
    else
        speed_text = "VEL: " .. tostring(math.floor(math.abs(ball.oForwardVel)))
    end

    local width = 430
    local height = 126

    djui_hud_set_color(0, 0, 0, 175)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 31, status_scale)

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(ball_status .. "  |  " .. speed_text, x, y + 56, info_scale)

    if hit_flash > 0 then
        djui_hud_set_color(255, 120, 80, 255)
        djui_hud_print_text("GOLPE FUERTE!", x, y + 76, 0.34)
    else
        djui_hud_set_color(220, 220, 220, 255)
        djui_hud_print_text(RESET_HINT, x, y + 78, info_scale)
    end

    djui_hud_set_color(180, 180, 180, 255)
    djui_hud_print_text("Escaleras: limitacion conocida de esta fisica", x, y + 99, 0.23)
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] Mashup A loaded — A1/A3.1 validation active")
