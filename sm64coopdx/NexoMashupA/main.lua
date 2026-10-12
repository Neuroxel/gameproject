-- name: NEXO Mashup A
-- description: A6.6 uses Mario's native physics/navigation and a visual Katamari follower.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "A6.6 MARIO = FISICA / BOLA = KATAMARI"
local RESET_HINT = "DPAD ABAJO: reiniciar progreso"

local BASE_SCALE = 1.80
local SCALE_PER_GOOMBA = 0.55
local MAX_SCALE = 6.00
local GROWTH_SPEED = 0.075

local absorbed_count = 0
local target_scale = BASE_SCALE
local visual_scale = BASE_SCALE
local absorb_flash = 0

-- Passive visual shells for absorbed enemies.
local attached_data = {}

-- Used only to animate visual rolling; never to move Mario.
local last_ball_x = nil
local last_ball_z = nil

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function ball_surface_radius()
    -- Approximation for the provisional Spiny Ball actor.
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
    absorb_flash = 0
    last_ball_x = nil
    last_ball_z = nil
    clear_attached_visuals()
end

local function update_target_scale()
    target_scale = math.min(BASE_SCALE + absorbed_count * SCALE_PER_GOOMBA, MAX_SCALE)
end

local function apply_visual_scale(obj)
    obj_scale_xyz(obj, visual_scale, visual_scale, visual_scale)
end

-- --------------------------------------------------------------------------
-- Passive attached Goombas
-- --------------------------------------------------------------------------

local function bhv_attached_goomba_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oAnimations = gObjectAnimations.goomba_seg8_anims_0801DA4C

    -- Visual only: no AI interaction, damage or collision.
    obj.oInteractType = 0
    obj.oIntangibleTimer = -1
    obj.oWallHitboxRadius = 0
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

    -- Rotate the stored radial direction with the visual ball.
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
-- Katamari visual/absorber object
-- --------------------------------------------------------------------------

local function bhv_nexo_ball_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 35

    apply_visual_scale(obj)

    -- CRITICAL: this object is not an authority for movement/collision anymore.
    -- Mario's native controller owns navigation, doors, stairs, slopes and rooms.
    obj.oInteractType = 0
    obj.oIntangibleTimer = -1
    obj.oWallHitboxRadius = 0
    obj.hitboxRadius = 0
    obj.hitboxHeight = 0
    obj.hurtboxRadius = 0
    obj.hurtboxHeight = 0

    cur_obj_become_intangible()
end

local function absorb_nearby_goombas(obj)
    local absorb_radius = ball_surface_radius() + 35

    local goomba = obj_get_first_with_behavior_id(id_bhvGoomba)
    local safety = 0

    while goomba ~= nil and safety < 256 do
        safety = safety + 1
        local next_goomba = obj_get_next_with_same_behavior_id(goomba)

        if dist_between_objects(obj, goomba) <= absorb_radius then
            spawn_attached_goomba(goomba, obj)
            obj_mark_for_deletion(goomba)

            absorbed_count = absorbed_count + 1
            update_target_scale()
            absorb_flash = 45

            cur_obj_play_sound_2(SOUND_GENERAL_COIN)
            print("[NEXO] Goomba attached. Total=" .. tostring(absorbed_count))
        end

        goomba = next_goomba
    end
end

local function bhv_nexo_ball_loop(obj)
    -- Growth remains visual and affects absorption radius, NOT world collision.
    if visual_scale < target_scale then
        visual_scale = math.min(visual_scale + GROWTH_SPEED, target_scale)
    elseif visual_scale > target_scale then
        visual_scale = math.max(visual_scale - GROWTH_SPEED, target_scale)
    end

    apply_visual_scale(obj)

    obj.oInteractType = 0
    obj.oIntangibleTimer = -1
    obj.oWallHitboxRadius = 0
    obj.hitboxRadius = 0
    obj.hitboxHeight = 0
    obj.hurtboxRadius = 0
    obj.hurtboxHeight = 0
    cur_obj_become_intangible()

    absorb_nearby_goombas(obj)
end

id_bhvNexoBall = hook_behavior(
    nil,
    OBJ_LIST_UNIMPORTANT,
    true,
    bhv_nexo_ball_init,
    bhv_nexo_ball_loop
)

local function spawn_ball_for_mario(m)
    local existing = get_ball()
    if existing ~= nil then
        obj_mark_for_deletion(existing)
    end

    local ball = spawn_non_sync_object(
        id_bhvNexoBall,
        E_MODEL_SPINY_BALL,
        m.pos.x,
        m.pos.y,
        m.pos.z,
        nil
    )

    last_ball_x = nil
    last_ball_z = nil

    if ball ~= nil then
        print("[NEXO] Mario-authoritative follower katamari spawned")
    end
end

local function update_ball_from_mario(m, ball)
    -- Use Mario's actual facing and native physics result. We never modify m.pos,
    -- m.vel, m.action or his collision state.
    local yaw = m.faceAngle.y

    -- Keep the visual katamari close enough that it reads as being pushed,
    -- but cap the distance so very large visual growth does not break doors/corridors.
    local offset = math.min(105 + ball_surface_radius() * 0.30, 180)

    local x = m.pos.x + sins(yaw) * offset
    local z = m.pos.z + coss(yaw) * offset

    -- Snap only the visual ball to the floor under its own visual center.
    local floor_y = find_floor_height(x, m.pos.y + 300, z)
    local y = m.pos.y

    if floor_y > -10000 then
        y = floor_y + 18
    end

    -- Derive a simple rolling animation from distance travelled.
    if last_ball_x ~= nil and last_ball_z ~= nil then
        local dx = x - last_ball_x
        local dz = z - last_ball_z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist > 0.05 then
            ball.oFaceAngleYaw = yaw
            ball.oFaceAnglePitch = ball.oFaceAnglePitch + dist * 420
        end
    else
        ball.oFaceAngleYaw = yaw
    end

    last_ball_x = x
    last_ball_z = z

    ball.oPosX = x
    ball.oPosY = y
    ball.oPosZ = z
    ball.oMoveAngleYaw = yaw

    ball.header.gfx.pos.x = x
    ball.header.gfx.pos.y = y
    ball.header.gfx.pos.z = z
end

local function mario_update(m)
    if m.playerIndex ~= 0 then
        return
    end

    if absorb_flash > 0 then
        absorb_flash = absorb_flash - 1
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

    -- Mario has already completed his native update at this hook.
    update_ball_from_mario(m, ball)
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
    local title_scale = 0.50
    local status_scale = 0.34
    local info_scale = 0.24

    local size_text = string.format("TAM: %.2f", visual_scale)
    local count_text = "PEGADOS: " .. tostring(absorbed_count)

    local width = 540
    local height = 146

    djui_hud_set_color(0, 0, 0, 175)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 27, status_scale)

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(count_text .. " | " .. size_text, x, y + 50, info_scale)

    if absorb_flash > 0 then
        djui_hud_set_color(120, 255, 120, 255)
        djui_hud_print_text("GOOMBA PEGADO +1", x, y + 70, 0.31)
    else
        djui_hud_set_color(220, 220, 220, 255)
        djui_hud_print_text(RESET_HINT, x, y + 72, info_scale)
    end

    djui_hud_set_color(180, 220, 255, 255)
    djui_hud_print_text("CONTROL: Mario normal (puertas/escaleras/pendientes nativas)", x, y + 96, 0.22)

    djui_hud_set_color(180, 180, 180, 255)
    djui_hud_print_text("La bola es visual + absorcion; NO bloquea superficies", x, y + 114, 0.22)
    djui_hud_print_text("Modelo con puntas = provisional", x, y + 130, 0.22)
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_ON_OBJECT_UNLOAD, on_object_unload)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] A6.5 rejected; A6.6 Mario-authoritative navigation active")
