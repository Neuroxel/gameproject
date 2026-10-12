-- name: NEXO Mashup A
-- description: NEXO Mashup Lab prototype. A4-A6: Goomba detection, absorption and real ball growth.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "A4-A6 KATAMARI TEST"
local RESET_HINT = "DPAD ABAJO: reiniciar progreso  |  B: golpe fuerte"

local BASE_SCALE = 1.15
local SCALE_PER_GOOMBA = 0.18
local MAX_SCALE = 3.25

local BASE_WALL_RADIUS = 55.0
local BASE_HITBOX_RADIUS = 95
local BASE_HITBOX_HEIGHT = 95

local absorbed_count = 0
local ball_scale = BASE_SCALE
local hit_flash = 0
local absorb_flash = 0

local function reset_progress()
    absorbed_count = 0
    ball_scale = BASE_SCALE
    absorb_flash = 0
    hit_flash = 0
end

local function update_scale_from_progress()
    ball_scale = math.min(BASE_SCALE + absorbed_count * SCALE_PER_GOOMBA, MAX_SCALE)
end

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function bhv_nexo_ball_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 35

    obj_scale(obj, ball_scale)

    obj.oGravity      = 2.50
    obj.oBounciness   = -0.35
    obj.oDragStrength = 0.00
    obj.oFriction     = 0.97
    obj.oBuoyancy     = -2.00

    local ratio = ball_scale / BASE_SCALE
    obj.oWallHitboxRadius = BASE_WALL_RADIUS * ratio
    obj.hitboxRadius = BASE_HITBOX_RADIUS * ratio
    obj.hitboxHeight = BASE_HITBOX_HEIGHT * ratio

    network_init_object(obj, true, nil)
end

local function absorb_nearby_goombas(obj)
    local ratio = ball_scale / BASE_SCALE
    local absorb_radius = 125 + 55 * ratio

    local goomba = obj_get_first_with_behavior_id(id_bhvGoomba)
    local safety = 0

    while goomba ~= nil and safety < 256 do
        safety = safety + 1
        local next_goomba = obj_get_next_with_same_behavior_id(goomba)

        if dist_between_objects(obj, goomba) <= absorb_radius then
            obj_mark_for_deletion(goomba)

            absorbed_count = absorbed_count + 1
            update_scale_from_progress()

            absorb_flash = 40
            obj.oVelY = math.max(obj.oVelY, 7)

            -- Audible feedback while the current object is the ball behavior.
            cur_obj_play_sound_2(SOUND_GENERAL_COIN)

            print("[NEXO] Goomba absorbed. Total: " .. tostring(absorbed_count))
        end

        goomba = next_goomba
    end
end

local function bhv_nexo_ball_loop(obj)
    local ratio = ball_scale / BASE_SCALE

    -- A6: growth is not cosmetic only. Visual scale and collision volumes grow together.
    obj_scale(obj, ball_scale)
    obj.oWallHitboxRadius = BASE_WALL_RADIUS * ratio
    obj.hitboxRadius = BASE_HITBOX_RADIUS * ratio
    obj.hitboxHeight = BASE_HITBOX_HEIGHT * ratio

    -- A4-A5: detect and absorb standard Goombas.
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

    -- Push radius grows with the ball so Mario can still make contact naturally.
    local push_radius = 70 + 45 * ratio
    local strong_hit_radius = push_radius + 75

    local strong_hit = ((m.controller.buttonPressed & B_BUTTON) ~= 0)
                       and distance_to_player < strong_hit_radius

    if strong_hit then
        obj.oMoveAngleYaw = angle_to_player + 0x8000

        -- Larger balls retain a strong hit, but not infinitely fast.
        local strong_speed = math.max(58, 78 - absorbed_count * 2)
        obj.oForwardVel = math.max(obj.oForwardVel, strong_speed)
        obj.oVelY = math.max(obj.oVelY, 18)

        if m.playerIndex == 0 then
            hit_flash = 24
            local_player_touch = true
        end

    elseif distance_to_player < push_radius then
        local xdiff = player.oPosX - obj.oPosX
        local zdiff = player.oPosZ - obj.oPosZ

        if distance_to_player > 1 then
            obj.oPosX = obj.oPosX - (push_radius - distance_to_player) / push_radius * xdiff
            obj.oPosZ = obj.oPosZ - (push_radius - distance_to_player) / push_radius * zdiff
        end

        obj.oMoveAngleYaw = angle_to_player + 0x8000

        local mario_speed = math.abs(m.forwardVel)

        -- Mild mass effect: each absorbed Goomba makes passive pushing a little heavier.
        local mass_factor = 1 + absorbed_count * 0.10
        local push = (2.5 + math.min(mario_speed * 0.10, 5.5)) / mass_factor

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

    -- Visible roll of the temporary 3D model.
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

    print("[NEXO] A4-A6 ball spawned")
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
    local title_scale = 0.56
    local status_scale = 0.40
    local info_scale = 0.27

    local ball = get_ball()
    local speed_text = "VEL: --"

    if ball ~= nil then
        speed_text = "VEL: " .. tostring(math.floor(math.abs(ball.oForwardVel)))
    end

    local size_text = string.format("TAM: %.2fx", ball_scale)
    local count_text = "GOOMBAS: " .. tostring(absorbed_count)

    local width = 455
    local height = 144

    djui_hud_set_color(0, 0, 0, 175)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 30, status_scale)

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(count_text .. "  |  " .. size_text .. "  |  " .. speed_text, x, y + 54, info_scale)

    if absorb_flash > 0 then
        djui_hud_set_color(120, 255, 120, 255)
        djui_hud_print_text("GOOMBA ABSORBIDO +1", x, y + 76, 0.34)
    elseif hit_flash > 0 then
        djui_hud_set_color(255, 120, 80, 255)
        djui_hud_print_text("GOLPE FUERTE!", x, y + 76, 0.34)
    else
        djui_hud_set_color(220, 220, 220, 255)
        djui_hud_print_text(RESET_HINT, x, y + 78, info_scale)
    end

    djui_hud_set_color(180, 180, 180, 255)
    djui_hud_print_text("Objetivo: rueda contra un Goomba y haz crecer la bola", x, y + 102, 0.23)
    djui_hud_print_text("Modelo con puntas = provisional; se reemplazara despues", x, y + 119, 0.23)
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] Mashup A loaded — A1-A3.1 PASS; A4-A6 validation active")
