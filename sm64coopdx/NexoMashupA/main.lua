-- name: NEXO Mashup A
-- description: A6.8 visual grounding + A7/A8 first progression slice.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "A6.8 + A7/A8 PROGRESION"
local RESET_HINT = "DPAD ABAJO: reiniciar progreso"

local BASE_SCALE = 1.80
local MAX_SCALE = 7.00
local GROWTH_SPEED = 0.070

-- Provisional Spiny Ball visual geometry.
local MODEL_BODY_RADIUS = 24.0
local MODEL_CENTER_Y_PER_SCALE = 8.5
local PICKUP_PADDING = 62.0

-- Natural visual roll.
local ROLL_VISUAL_FACTOR = 0.35
local YAW_VISUAL_STEP = 0x180
local ANGLE_UNITS_PER_RADIAN = 10430.378

-- Progression / feedback.
local LOCK_WARNING_MARGIN = 50.0
local LOCK_FLASH_FRAMES = 42
local ABSORB_FLASH_FRAMES = 38

local absorbed_count = 0
local growth_progress = 0.0
local target_scale = BASE_SCALE
local visual_scale = BASE_SCALE

local counts = {
    COIN = 0,
    GOOMBA = 0,
    BOBOMB = 0,
}

local absorb_flash = 0
local absorb_label = ""
local lock_flash = 0
local lock_label = ""

-- Passive visual shells for absorbed things.
local attached_data = {}

-- Used only to animate visual rolling; never to move Mario.
local last_ball_x = nil
local last_ball_z = nil

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function ball_surface_radius()
    return MODEL_BODY_RADIUS * visual_scale
end

local function ball_center_y_offset()
    -- spiny_ball_geo places the animated mesh at Y=-34 inside a GEO_SCALE 0.25.
    -- 34 * 0.25 = 8.5 units per object scale.
    return MODEL_CENTER_Y_PER_SCALE * visual_scale
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

local function update_target_scale()
    target_scale = math.min(BASE_SCALE + growth_progress, MAX_SCALE)
end

local function clear_attached_visuals()
    if id_bhvNexoAttachedVisual == nil then
        attached_data = {}
        return
    end

    local obj = obj_get_first_with_behavior_id(id_bhvNexoAttachedVisual)
    local safety = 0

    while obj ~= nil and safety < 512 do
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
    growth_progress = 0.0
    target_scale = BASE_SCALE
    visual_scale = BASE_SCALE

    counts.COIN = 0
    counts.GOOMBA = 0
    counts.BOBOMB = 0

    absorb_flash = 0
    absorb_label = ""
    lock_flash = 0
    lock_label = ""

    last_ball_x = nil
    last_ball_z = nil

    clear_attached_visuals()
end

local function apply_visual_scale(obj)
    obj_scale_xyz(obj, visual_scale, visual_scale, visual_scale)
end

-- --------------------------------------------------------------------------
-- A7/A8 pickup definitions
-- --------------------------------------------------------------------------

local PICKUPS = {
    -- Coins: always available, tiny growth.
    {
        key = "COIN",
        label = "MONEDA",
        behavior = id_bhvYellowCoin,
        model = E_MODEL_YELLOW_COIN,
        threshold = 1.80,
        growth = 0.08,
        visualScale = 0.80,
        attachOffset = 8,
        floorClearance = 4,
        centerY = 0,
        animations = nil,
        animationIndex = 0,
    },
    {
        key = "COIN",
        label = "MONEDA",
        behavior = id_bhvSingleCoinGetsSpawned,
        model = E_MODEL_YELLOW_COIN,
        threshold = 1.80,
        growth = 0.08,
        visualScale = 0.80,
        attachOffset = 8,
        floorClearance = 4,
        centerY = 0,
        animations = nil,
        animationIndex = 0,
    },

    -- Goomba: base enemy.
    {
        key = "GOOMBA",
        label = "GOOMBA",
        behavior = id_bhvGoomba,
        model = E_MODEL_GOOMBA,
        threshold = 1.80,
        growth = 0.35,
        visualScale = 0.90,
        attachOffset = 28,
        floorClearance = 10,
        centerY = 30,
        animations = gObjectAnimations.goomba_seg8_anims_0801DA4C,
        animationIndex = 0,
    },

    -- Bob-omb: first locked tier. Four Goombas or equivalent are enough.
    {
        key = "BOBOMB",
        label = "BOB-OMB",
        behavior = id_bhvBobomb,
        model = E_MODEL_BLACK_BOBOMB,
        threshold = 2.70,
        growth = 0.50,
        visualScale = 0.90,
        attachOffset = 25,
        floorClearance = 10,
        centerY = 25,
        animations = gObjectAnimations.bobomb_seg8_anims_0802396C,
        animationIndex = 0,
    },
}

-- --------------------------------------------------------------------------
-- Generic passive attached visual
-- --------------------------------------------------------------------------

local function bhv_attached_visual_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE

    obj.oInteractType = 0
    obj.oIntangibleTimer = -1
    obj.oWallHitboxRadius = 0
    obj.hitboxRadius = 0
    obj.hitboxHeight = 0
    obj.hurtboxRadius = 0
    obj.hurtboxHeight = 0

    obj_scale(obj, 1.0)
end

local function bhv_attached_visual_loop(obj)
    local data = attached_data[tostring(obj._pointer)]
    local ball = get_ball()

    if data == nil or ball == nil then
        obj_mark_for_deletion(obj)
        return
    end

    if not data.initialized then
        obj_scale(obj, data.visualScale)

        if data.animations ~= nil then
            obj.oAnimations = data.animations
            cur_obj_init_animation(data.animationIndex)
        end

        data.initialized = true
    elseif data.animations ~= nil then
        cur_obj_init_animation(data.animationIndex)
    end

    -- Rotate stored radial direction with the visual ball.
    local dyaw = ball.oFaceAngleYaw - data.lastYaw
    local dpitch = ball.oFaceAnglePitch - data.lastPitch

    data.dx, data.dy, data.dz = rotate_y(data.dx, data.dy, data.dz, dyaw)
    data.dx, data.dy, data.dz = rotate_x(data.dx, data.dy, data.dz, dpitch)
    data.dx, data.dy, data.dz = normalize3(data.dx, data.dy, data.dz)

    data.lastYaw = ball.oFaceAngleYaw
    data.lastPitch = ball.oFaceAnglePitch

    -- Center is OUTSIDE the red sphere, not embedded inside it.
    local r = ball_surface_radius() + data.attachOffset

    local x = ball.oPosX + data.dx * r
    local y = ball.oPosY + data.dy * r
    local z = ball.oPosZ + data.dz * r

    -- Visual-only floor clamp: bottom-side attachments should not disappear
    -- deeply into terrain while the katamari rolls.
    local floor_y = find_floor_height(x, ball.oPosY + 350, z)
    if floor_y > -10000 then
        y = math.max(y, floor_y + data.floorClearance)
    end

    obj.oPosX = x
    obj.oPosY = y
    obj.oPosZ = z

    -- Keep the same tumbling language as before, but at the slower A6.7 rate.
    obj.oFaceAngleYaw = ball.oFaceAngleYaw + data.yawOffset
    obj.oFaceAnglePitch = ball.oFaceAnglePitch
    obj.oFaceAngleRoll = ball.oFaceAngleRoll

    obj.header.gfx.pos.x = x
    obj.header.gfx.pos.y = y
    obj.header.gfx.pos.z = z
end

id_bhvNexoAttachedVisual = hook_behavior(
    nil,
    OBJ_LIST_UNIMPORTANT,
    true,
    bhv_attached_visual_init,
    bhv_attached_visual_loop
)

local function spawn_attached_visual(target, ball, spec)
    local dx = target.oPosX - ball.oPosX
    local dy = (target.oPosY + spec.centerY) - ball.oPosY
    local dz = target.oPosZ - ball.oPosZ
    dx, dy, dz = normalize3(dx, dy, dz)

    local attached = spawn_non_sync_object(
        id_bhvNexoAttachedVisual,
        spec.model,
        target.oPosX,
        target.oPosY,
        target.oPosZ,
        nil
    )

    if attached ~= nil then
        attached_data[tostring(attached._pointer)] = {
            dx = dx,
            dy = dy,
            dz = dz,
            lastYaw = ball.oFaceAngleYaw,
            lastPitch = ball.oFaceAnglePitch,
            yawOffset = (absorbed_count * 0x1F1F) & 0xFFFF,

            visualScale = spec.visualScale,
            attachOffset = spec.attachOffset,
            floorClearance = spec.floorClearance,
            animations = spec.animations,
            animationIndex = spec.animationIndex,
            initialized = false,
        }
    end
end

-- --------------------------------------------------------------------------
-- Katamari visual / absorber
-- --------------------------------------------------------------------------

local function bhv_nexo_ball_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 0

    apply_visual_scale(obj)

    -- Mario remains the ONLY navigation/collision authority.
    obj.oInteractType = 0
    obj.oIntangibleTimer = -1
    obj.oWallHitboxRadius = 0
    obj.hitboxRadius = 0
    obj.hitboxHeight = 0
    obj.hurtboxRadius = 0
    obj.hurtboxHeight = 0

    cur_obj_become_intangible()
end

local function show_locked_feedback(spec)
    if lock_flash <= 0 then
        lock_label = spec.label .. " requiere TAM " .. string.format("%.2f", spec.threshold)
        lock_flash = LOCK_FLASH_FRAMES
    end
end

local function absorb_target(target, ball, spec)
    spawn_attached_visual(target, ball, spec)
    obj_mark_for_deletion(target)

    absorbed_count = absorbed_count + 1
    counts[spec.key] = counts[spec.key] + 1

    growth_progress = growth_progress + spec.growth
    update_target_scale()

    absorb_label = spec.label .. " PEGADO +" .. string.format("%.2f", spec.growth)
    absorb_flash = ABSORB_FLASH_FRAMES

    cur_obj_play_sound_2(SOUND_GENERAL_COIN)

    print(
        "[NEXO] Absorbed " .. spec.label
        .. " total=" .. tostring(absorbed_count)
        .. " targetScale=" .. tostring(target_scale)
    )
end

local function scan_pickup_type(ball, spec)
    local obj = obj_get_first_with_behavior_id(spec.behavior)
    local safety = 0

    local pickup_radius = ball_surface_radius() + PICKUP_PADDING
    local warning_radius = pickup_radius + LOCK_WARNING_MARGIN

    while obj ~= nil and safety < 512 do
        safety = safety + 1
        local next_obj = obj_get_next_with_same_behavior_id(obj)

        local dist = dist_between_objects(ball, obj)

        if dist <= pickup_radius then
            if visual_scale + 0.001 >= spec.threshold then
                absorb_target(obj, ball, spec)
            else
                show_locked_feedback(spec)
            end
        elseif dist <= warning_radius and visual_scale + 0.001 < spec.threshold then
            show_locked_feedback(spec)
        end

        obj = next_obj
    end
end

local function scan_all_pickups(ball)
    for _, spec in ipairs(PICKUPS) do
        scan_pickup_type(ball, spec)
    end
end

local function bhv_nexo_ball_loop(obj)
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

    scan_all_pickups(obj)
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
        print("[NEXO] A6.8/A7 follower katamari spawned")
    end
end

local function update_ball_from_mario(m, ball)
    local yaw = m.faceAngle.y

    -- Preserve A6.6 navigation architecture.
    local offset = math.min(112 + ball_surface_radius() * 0.25, 155)

    local x = m.pos.x + sins(yaw) * offset
    local z = m.pos.z + coss(yaw) * offset

    local floor_y = find_floor_height(x, m.pos.y + 400, z)
    local y = m.pos.y

    if floor_y > -10000 then
        -- A6.8: the center rises as the visible radius grows.
        -- Extra offset compensates for the model's internal Y translation.
        y = floor_y + ball_surface_radius() + ball_center_y_offset()
    end

    if last_ball_x ~= nil and last_ball_z ~= nil then
        local dx = x - last_ball_x
        local dz = z - last_ball_z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist > 0.05 then
            local radius = math.max(ball_surface_radius(), 24)
            local roll_delta = (dist / radius) * ANGLE_UNITS_PER_RADIAN * ROLL_VISUAL_FACTOR

            ball.oFaceAnglePitch = ball.oFaceAnglePitch + math.floor(roll_delta)

            ball.oFaceAngleYaw = approach_s16_symmetric(
                ball.oFaceAngleYaw,
                yaw,
                YAW_VISUAL_STEP
            )
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

    if lock_flash > 0 then
        lock_flash = lock_flash - 1
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
    local title_scale = 0.48
    local status_scale = 0.32
    local info_scale = 0.22

    local size_text = string.format("TAM: %.2f", visual_scale)
    local count_text = "OBJ: " .. tostring(absorbed_count)

    local width = 570
    local height = 169

    djui_hud_set_color(0, 0, 0, 175)
    djui_hud_render_rect(x - 10, y - 10, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, title_scale)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 26, status_scale)

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(
        count_text .. " | " .. size_text
        .. " | M:" .. tostring(counts.COIN)
        .. " G:" .. tostring(counts.GOOMBA)
        .. " B:" .. tostring(counts.BOBOMB),
        x, y + 48, info_scale
    )

    if absorb_flash > 0 then
        djui_hud_set_color(120, 255, 120, 255)
        djui_hud_print_text(absorb_label, x, y + 68, 0.29)
    elseif lock_flash > 0 then
        djui_hud_set_color(255, 150, 90, 255)
        djui_hud_print_text("DEMASIADO GRANDE: " .. lock_label, x, y + 68, 0.27)
    else
        djui_hud_set_color(220, 220, 220, 255)
        djui_hud_print_text(RESET_HINT, x, y + 70, info_scale)
    end

    djui_hud_set_color(180, 220, 255, 255)
    djui_hud_print_text("TIER ACTUAL: moneda + Goomba | Bob-omb requiere TAM 2.70", x, y + 94, 0.21)

    djui_hud_set_color(180, 180, 180, 255)
    djui_hud_print_text("Bola sube con su radio al crecer; attachments fuera de superficie", x, y + 113, 0.20)
    djui_hud_print_text("Mario conserva fisica nativa; bola sin colision de mundo", x, y + 130, 0.20)
    djui_hud_print_text("Siguiente tras PASS: Koopa + objetos mayores + scoring", x, y + 147, 0.20)
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_ON_OBJECT_UNLOAD, on_object_unload)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] A6.8 grounding + A7/A8 first progression slice active")
