-- name: NEXO Mashup A
-- description: A6.5 direct Katamari-style control + visible attached Goombas.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "A6.5 CONTROL + OBJETOS PEGADOS"
local RESET_HINT = "DPAD ABAJO: reiniciar  |  B: DASH"

-- Growth already validated in A6.1.
local BASE_SCALE = 1.80
local SCALE_PER_GOOMBA = 0.55
local MAX_SCALE = 6.00
local GROWTH_SPEED = 0.075

local BASE_WALL_RADIUS = 70.0
local BASE_HITBOX_RADIUS = 125
local BASE_HITBOX_HEIGHT = 125

-- Direct-control tuning. The ball is no longer a loose physics prop that Mario
-- has to chase; analog input drives it directly, Katamari-style.
local STEER_RATE = 0x1600
local MAX_DRIVE_SPEED = 34.0
local DRIVE_ACCEL = 2.2
local DRIVE_BRAKE = 2.8
local DASH_SPEED = 52.0

local absorbed_count = 0
local target_scale = BASE_SCALE
local visual_scale = BASE_SCALE

local control_mag = 0.0
local control_yaw = 0
local dash_request = false

local absorb_flash = 0
local dash_flash = 0

-- Non-networked visual shells for absorbed objects.
local attached_data = {}

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function ball_surface_radius()
    -- Approximation matched to the provisional Spiny Ball model.
    return 48.0 * visual_scale + 28.0
end

local function normalize3(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 0.001 then
        return 0, 1, 0
    end
    return x / len, y / len, z / len
end

local function rotate_y(x, y, z, a)
    local s = sins(a)
    local c = coss(a)
    return x * c + z * s, y, z * c - x * s
end

local function rotate_x(x, y, z, a)
    local s = sins(a)
    local c = coss(a)
    return x, y * c - z * s, y * s + z * c
end

local function clear_attached_visuals()
    if id_bhvNexoAttachedGoomba == nil then
        attached_data = {}
        return
    end

    local obj = obj_get_first_with_behavior_id(id_bhvNexoAttachedGoomba)
    local safety = 0
    while obj ~= nil and safety < 256 do
        safety = safety + 1
        local nxt = obj_get_next_with_same_behavior_id(obj)
        attached_data[tostring(obj._pointer)] = nil
        obj_mark_for_deletion(obj)
        obj = nxt
    end

    attached_data = {}
end

local function reset_progress()
    absorbed_count = 0
    target_scale = BASE_SCALE
    visual_scale = BASE_SCALE
    control_mag = 0.0
    dash_request = false
    absorb_flash = 0
    dash_flash = 0
    clear_attached_visuals()
end

local function update_target_scale()
    target_scale = math.min(BASE_SCALE + absorbed_count * SCALE_PER_GOOMBA, MAX_SCALE)
end

local function apply_visual_scale(obj)
    obj_scale_xyz(obj, visual_scale, visual_scale, visual_scale)
end

local function update_collision_scale(obj)
    local ratio = visual_scale / BASE_SCALE
    obj.oWallHitboxRadius = BASE_WALL_RADIUS * ratio
    obj.hitboxRadius = BASE_HITBOX_RADIUS * ratio
    obj.hitboxHeight = BASE_HITBOX_HEIGHT * ratio
end

-- --------------------------------------------------------------------------
-- Attached Goomba visuals
-- --------------------------------------------------------------------------

local function bhv_attached_goomba_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oAnimations = gObjectAnimations.goomba_seg8_anims_0801DA4C
    obj.oInteractType = 0
    obj.oIntangibleTimer = -1
    obj.hitboxRadius = 0
    obj.hitboxHeight = 0
    obj.hurtboxRadius = 0
    obj.hurtboxHeight = 0
    obj_scale(obj, 0.90)
end

local function bhv_attached_goomba_loop(obj)
    local data = attached_data[tostring(obj._pointer)]
    local ball = get_ball()

    if data == nil or ball == nil then
        obj_mark_for_deletion(obj)
        return
    end

    -- Rotate the stored radial vector by the ball's incremental rotation.
    local dyaw = ball.oFaceAngleYaw - data.lastYaw
    local dpitch = ball.oFaceAnglePitch - data.lastPitch

    data.dx, data.dy, data.dz = rotate_y(data.dx, data.dy, data.dz, dyaw)
    data.dx, data.dy, data.dz = rotate_x(data.dx, data.dy, data.dz, dpitch)
    data.dx, data.dy, data.dz = normalize3(data.dx, data.dy, data.dz)

    data.lastYaw = ball.oFaceAngleYaw
    data.lastPitch = ball.oFaceAnglePitch

    local r = ball_surface_radius() + 24

    obj.oPosX = ball.oPosX + data.dx * r
    obj.oPosY = ball.oPosY + data.dy * r
    obj.oPosZ = ball.oPosZ + data.dz * r

    -- Make the passive shell tumble with the katamari.
    obj.oFaceAngleYaw = ball.oFaceAngleYaw + data.yawOffset
    obj.oFaceAnglePitch = ball.oFaceAnglePitch
    obj.oFaceAngleRoll = ball.oFaceAngleRoll

    obj.header.gfx.pos.x = obj.oPosX
    obj.header.gfx.pos.y = obj.oPosY
    obj.header.gfx.pos.z = obj.oPosZ

    cur_obj_init_animation(0)
end

id_bhvNexoAttachedGoomba = hook_behavior(
    nil,
    OBJ_LIST_UNIMPORTANT,
    true,
    bhv_attached_goomba_init,
    bhv_attached_goomba_loop
)

local function spawn_attached_goomba(goomba, ball)
    local dx = goomba.oPosX - ball.oPosX
    local dy = (goomba.oPosY + 30) - ball.oPosY
    local dz = goomba.oPosZ - ball.oPosZ
    dx, dy, dz = normalize3(dx, dy, dz)

    local attached = spawn_non_sync_object(
        id_bhvNexoAttachedGoomba,
        E_MODEL_GOOMBA,
        goomba.oPosX,
        goomba.oPosY,
        goomba.oPosZ,
        nil
    )

    if attached ~= nil then
        attached_data[tostring(attached._pointer)] = {
            dx = dx,
            dy = dy,
            dz = dz,
            lastYaw = ball.oFaceAngleYaw,
            lastPitch = ball.oFaceAnglePitch,
            yawOffset = (absorbed_count * 0x2222) & 0xFFFF,
        }
    end
end

-- --------------------------------------------------------------------------
-- Katamari ball
-- --------------------------------------------------------------------------

local function bhv_nexo_ball_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 35

    apply_visual_scale(obj)

    obj.oGravity = 2.50
    obj.oBounciness = -0.20
    obj.oDragStrength = 0.00
    obj.oFriction = 0.96
    obj.oBuoyancy = -2.00

    update_collision_scale(obj)

    -- Mario is visually placed behind the ball; he should not physically shove it.
    cur_obj_become_intangible()

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
            -- Preserve a passive visible shell before deleting the active enemy.
            spawn_attached_goomba(goomba, obj)
            obj_mark_for_deletion(goomba)

            absorbed_count = absorbed_count + 1
            update_target_scale()

            absorb_flash = 45
            obj.oVelY = math.max(obj.oVelY, 4)
            cur_obj_play_sound_2(SOUND_GENERAL_COIN)

            print("[NEXO] Goomba attached. Total=" .. tostring(absorbed_count))
        end

        goomba = next_goomba
    end
end

local function approach_speed(current, target, accel, brake)
    if current < target then
        return math.min(current + accel, target)
    elseif current > target then
        return math.max(current - brake, target)
    end
    return current
end

local function apply_step_assist(obj)
    if control_mag < 2 then
        return
    end

    -- Small ledges/steps should not make a directly controlled katamari feel stuck.
    local probe = 70 + 18 * (visual_scale / BASE_SCALE)
    local px = obj.oPosX + sins(obj.oMoveAngleYaw) * probe
    local pz = obj.oPosZ + coss(obj.oMoveAngleYaw) * probe

    local current_floor = find_floor_height(obj.oPosX, obj.oPosY + 160, obj.oPosZ)
    local ahead_floor = find_floor_height(px, obj.oPosY + 160, pz)
    local rise = ahead_floor - current_floor

    if rise > 1 and rise <= 70 and obj.oVelY <= 0 then
        obj.oPosY = obj.oPosY + math.min(rise, 9)
    end
end

local function bhv_nexo_ball_loop(obj)
    -- Smooth visible growth.
    if visual_scale < target_scale then
        visual_scale = math.min(visual_scale + GROWTH_SPEED, target_scale)
    elseif visual_scale > target_scale then
        visual_scale = math.max(visual_scale - GROWTH_SPEED, target_scale)
    end

    apply_visual_scale(obj)
    update_collision_scale(obj)
    cur_obj_become_intangible()

    absorb_nearby_goombas(obj)

    -- Direct analog control, camera-relative through Mario's intendedYaw.
    if control_mag > 1.0 then
        obj.oMoveAngleYaw = approach_s16_symmetric(
            obj.oMoveAngleYaw,
            control_yaw,
            STEER_RATE
        )

        local input01 = math.min(control_mag / 32.0, 1.0)

        -- Very mild mass penalty only; control should remain pleasant as the ball grows.
        local mass_factor = 1.0 + absorbed_count * 0.025
        local target_speed = (8.0 + input01 * (MAX_DRIVE_SPEED - 8.0)) / mass_factor

        obj.oForwardVel = approach_speed(
            obj.oForwardVel,
            target_speed,
            DRIVE_ACCEL,
            DRIVE_BRAKE
        )
    else
        obj.oForwardVel = approach_speed(obj.oForwardVel, 0, 0, 3.2)
    end

    if dash_request then
        obj.oForwardVel = math.max(obj.oForwardVel, DASH_SPEED)
        dash_request = false
        dash_flash = 24
    end

    apply_step_assist(obj)

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

    -- Roll while moving. Keep roll axis simple so attached objects can track it.
    obj.oFaceAngleYaw = obj.oMoveAngleYaw
    obj.oFaceAnglePitch = obj.oFaceAnglePitch + obj.oForwardVel * 120
    obj.oFaceAngleRoll = 0
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

    print("[NEXO] Direct-control katamari spawned")
end

local function place_mario_behind_ball(m, ball)
    -- Keep Mario visually pushing the katamari while the katamari itself is controlled.
    local behind = ball_surface_radius() + 70
    local yaw = ball.oMoveAngleYaw

    local x = ball.oPosX - sins(yaw) * behind
    local z = ball.oPosZ - coss(yaw) * behind
    local floor_y = find_floor_height(x, ball.oPosY + 250, z)

    -- Avoid snapping Mario to the global lower limit if no floor exists.
    local y = ball.oPosY
    if floor_y > -10000 then
        y = floor_y
    end

    m.pos.x = x
    m.pos.y = y
    m.pos.z = z

    m.vel.x = 0
    m.vel.y = 0
    m.vel.z = 0
    m.forwardVel = 0

    m.faceAngle.y = yaw

    m.marioObj.oPosX = x
    m.marioObj.oPosY = y
    m.marioObj.oPosZ = z
    m.marioObj.oMoveAngleYaw = yaw
    m.marioObj.oFaceAngleYaw = yaw

    m.marioObj.header.gfx.pos.x = x
    m.marioObj.header.gfx.pos.y = y
    m.marioObj.header.gfx.pos.z = z
end

local function mario_update(m)
    if m.playerIndex ~= 0 then
        return
    end

    -- Capture the CURRENT frame's camera-relative analog intent after Mario input processing.
    control_mag = m.intendedMag
    control_yaw = m.intendedYaw

    if absorb_flash > 0 then
        absorb_flash = absorb_flash - 1
    end
    if dash_flash > 0 then
        dash_flash = dash_flash - 1
    end

    local ball = get_ball()

    if ball == nil then
        spawn_ball_for_mario(m)
        return
    end

    if (m.controller.buttonPressed & D_JPAD) ~= 0 then
        reset_progress()
        spawn_ball_for_mario(m)
        return
    end

    if (m.controller.buttonPressed & B_BUTTON) ~= 0 then
        dash_request = true
    end

    place_mario_behind_ball(m, ball)
end

local function on_level_init()
    reset_progress()
end

local function on_object_unload(obj)
    if obj ~= nil and obj._pointer ~= nil then
        attached_data[tostring(obj._pointer)] = nil
    end
end

local function on_hud_render()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)

    local x = 28
    local y = 28
    local title_scale = 0.52
    local status_scale = 0.36
    local info_scale = 0.24

    local ball = get_ball()
    local speed_text = "VEL: --"
    if ball ~= nil then
        speed_text = "VEL: " .. tostring(math.floor(math.abs(ball.oForwardVel)))
    end

    local size_text = string.format("TAM: %.2f", visual_scale)
    local count_text = "PEGADOS: " .. tostring(absorbed_count)

    local width = 515
    local height = 151

    djui_hud_set_color(0, 0, 0, 175)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 28, status_scale)

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(count_text .. " | " .. size_text .. " | " .. speed_text, x, y + 51, info_scale)

    if absorb_flash > 0 then
        djui_hud_set_color(120, 255, 120, 255)
        djui_hud_print_text("GOOMBA PEGADO +1", x, y + 72, 0.31)
    elseif dash_flash > 0 then
        djui_hud_set_color(255, 140, 80, 255)
        djui_hud_print_text("DASH!", x, y + 72, 0.31)
    else
        djui_hud_set_color(220, 220, 220, 255)
        djui_hud_print_text(RESET_HINT, x, y + 74, info_scale)
    end

    djui_hud_set_color(180, 220, 255, 255)
    djui_hud_print_text("Stick: controla directamente la bola (relativo a camara)", x, y + 98, 0.23)

    djui_hud_set_color(180, 180, 180, 255)
    djui_hud_print_text("Goombas absorbidos quedan como cascarones visuales pasivos", x, y + 117, 0.22)
    djui_hud_print_text("Modelo con puntas sigue siendo provisional", x, y + 134, 0.22)
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_ON_OBJECT_UNLOAD, on_object_unload)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] A6 growth PASS; A6.5 direct control + attachments active")
