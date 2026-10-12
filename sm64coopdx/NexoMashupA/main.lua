-- name: NEXO Mashup A
-- description: NEXO Mashup Lab prototype. A1-A3: visible physics ball that Mario can push.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "A1-A3 BALL TEST"
local RESET_HINT = "DPAD ABAJO: reiniciar bola"

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function bhv_nexo_ball_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 35

    -- Visual size for the first prototype.
    cur_obj_scale(0.80)

    -- Physics adapted from the official SM64CoopDX custom ball example.
    obj.oWallHitboxRadius = 55.0
    obj.oGravity          = 2.50
    obj.oBounciness       = -0.35
    obj.oDragStrength     = 0.00
    obj.oFriction         = 0.97
    obj.oBuoyancy         = -2.00

    obj.hitboxRadius = 90
    obj.hitboxHeight = 90

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

    -- Mario can push the ball by walking/running into it.
    -- Attacking gives a stronger shove.
    local radius = 110
    local push_strength = 7

    if (m.action & ACT_FLAG_ATTACKING) ~= 0 then
        radius = 150
        push_strength = 16
    end

    if distance_to_player < radius then
        local xdiff = player.oPosX - obj.oPosX
        local zdiff = player.oPosZ - obj.oPosZ

        if distance_to_player > 1 then
            obj.oPosX = obj.oPosX - (radius - distance_to_player) / radius * xdiff
            obj.oPosZ = obj.oPosZ - (radius - distance_to_player) / radius * zdiff
        end

        obj.oMoveAngleYaw = angle_to_player + 0x8000
        obj.oForwardVel = math.min(obj.oForwardVel + push_strength, 70)

        if (m.action & ACT_FLAG_ATTACKING) ~= 0 then
            obj.oVelY = obj.oVelY + 8.0
        end

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

    -- Make the visual model visibly roll.
    obj.oFaceAngleYaw = obj.oMoveAngleYaw
    obj.oFaceAnglePitch = obj.oFaceAnglePitch + obj.oForwardVel * 110

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
    local y = m.pos.y + 80
    local z = m.pos.z + coss(m.faceAngle.y) * distance

    spawn_sync_object(
        id_bhvNexoBall,
        E_MODEL_BOWLING_BALL,
        x, y, z,
        nil
    )

    print("[NEXO] A1-A3 ball spawned")
end

local function mario_update(m)
    if m.playerIndex ~= 0 then
        return
    end

    -- Automatic spawn keeps the prototype usable without setup knowledge.
    if get_ball() == nil then
        spawn_ball_for_mario(m)
        return
    end

    -- Manual reset/reposition in case the ball gets stuck.
    if (m.controller.buttonPressed & D_JPAD) ~= 0 then
        spawn_ball_for_mario(m)
    end
end

local function on_hud_render()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)

    local x = 28
    local y = 28
    local title_scale = 0.62
    local status_scale = 0.46
    local hint_scale = 0.30

    local ball = get_ball()
    local ball_status = "BOLA: ACTIVA"
    if ball == nil then
        ball_status = "BOLA: REAPARECIENDO"
    end

    local width = 390
    local height = 108

    djui_hud_set_color(0, 0, 0, 175)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 32, status_scale)

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(ball_status, x, y + 58, hint_scale)

    djui_hud_set_color(220, 220, 220, 255)
    djui_hud_print_text(RESET_HINT, x, y + 78, hint_scale)
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] Mashup A loaded — A0 PASS, A1-A3 validation active")
