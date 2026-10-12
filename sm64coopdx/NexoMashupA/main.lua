-- name: NEXO Mashup A
-- description: Vertical slice M1: Katamari cargo, rigid attachments, compact mode and NEXO Gate handoff.

local TITLE = "NEXO MASHUP LAB"
local STATUS = "M1 CARGA IMPOSIBLE"
local RESET_HINT = "DPAD ABAJO: reiniciar mision"

-- ============================================================================
-- Core scale model
-- ============================================================================

local BASE_SCALE = 1.80
local MAX_LOGICAL_SCALE = 8.00
local GROWTH_SPEED = 0.070
local COMPACT_SPEED = 0.16
local EXPAND_SPEED = 0.055

-- Provisional Spiny Ball visual geometry.
local MODEL_BODY_RADIUS = 24.0
local MODEL_CENTER_Y_PER_SCALE = 8.5
local PICKUP_PADDING = 62.0

-- Visual roll.
local ROLL_VISUAL_FACTOR = 0.35
local YAW_VISUAL_STEP = 0x180
local ANGLE_UNITS_PER_RADIAN = 10430.378

-- Compact-mode clearance.
local MIN_COMPACT_SCALE = 1.20
local COMPACT_MARGIN = 18.0
local COMPACT_RAY_EXTRA = 90.0

-- Feedback.
local LOCK_WARNING_MARGIN = 50.0
local LOCK_FLASH_FRAMES = 42
local ABSORB_FLASH_FRAMES = 38

-- ============================================================================
-- Mission M1
-- ============================================================================

local MISSION_ACTIVE = 0
local MISSION_RETURN = 1
local MISSION_COMPLETE = 2

local M1_REQ_COINS = 5
local M1_REQ_GOOMBAS = 4
local M1_REQ_BOBOMBS = 2
local M1_REQ_SCALE = 3.80

local M1_PORTAL_RADIUS = 175.0
local M1_TARGET_WORLD = "DOOM"

local mission_state = MISSION_ACTIVE
local mission_started = false
local mission_origin = { x = 0, y = 0, z = 0 }
local mission_start_frame = 0
local mission_end_frame = 0
local mission_score = 0
local mission_best_score = mod_storage_load_integer("m1_best_score", 0)

-- ============================================================================
-- Runtime state
-- ============================================================================

local absorbed_count = 0
local growth_progress = 0.0

-- Logical scale controls progression. Visual scale can compact in tight spaces.
local logical_scale = BASE_SCALE
local visual_scale = BASE_SCALE
local visual_target_scale = BASE_SCALE
local compact_active = false
local clearance_scale = MAX_LOGICAL_SCALE

local counts = {
    COIN = 0,
    GOOMBA = 0,
    BOBOMB = 0,
}

local absorb_flash = 0
local absorb_label = ""
local lock_flash = 0
local lock_label = ""

-- Passive rigid visual shells.
local attached_data = {}

-- Visual rolling only.
local last_ball_x = nil
local last_ball_z = nil

-- ============================================================================
-- General helpers
-- ============================================================================

local function get_ball()
    return obj_get_first_with_behavior_id(id_bhvNexoBall)
end

local function get_gate()
    if id_bhvNexoGate == nil then return nil end
    return obj_get_first_with_behavior_id(id_bhvNexoGate)
end

local function ball_surface_radius()
    return MODEL_BODY_RADIUS * visual_scale
end

local function logical_ball_radius()
    return MODEL_BODY_RADIUS * logical_scale
end

local function ball_center_y_offset()
    return MODEL_CENTER_Y_PER_SCALE * visual_scale
end

local function normalize3(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 0.001 then
        return 0, 1, 0
    end
    return x / len, y / len, z / len
end

local function distance3(ax, ay, az, bx, by, bz)
    local dx = bx - ax
    local dy = by - ay
    local dz = bz - az
    return math.sqrt(dx * dx + dy * dy + dz * dz)
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

local function set_object_visible(obj, visible)
    if visible then
        obj.header.gfx.node.flags = obj.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
    else
        obj.header.gfx.node.flags = obj.header.gfx.node.flags | GRAPH_RENDER_INVISIBLE
    end
end

local function update_logical_scale()
    logical_scale = math.min(BASE_SCALE + growth_progress, MAX_LOGICAL_SCALE)
end

local function format_seconds(frames)
    return string.format("%.1f", math.max(frames, 0) / 30.0)
end

-- ============================================================================
-- Rigid attachment cleanup / reset
-- ============================================================================

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

local function clear_gate()
    local gate = get_gate()
    if gate ~= nil then
        obj_mark_for_deletion(gate)
    end
end

local function reset_progress()
    absorbed_count = 0
    growth_progress = 0.0

    logical_scale = BASE_SCALE
    visual_scale = BASE_SCALE
    visual_target_scale = BASE_SCALE
    clearance_scale = MAX_LOGICAL_SCALE
    compact_active = false

    counts.COIN = 0
    counts.GOOMBA = 0
    counts.BOBOMB = 0

    absorb_flash = 0
    absorb_label = ""
    lock_flash = 0
    lock_label = ""

    last_ball_x = nil
    last_ball_z = nil

    mission_state = MISSION_ACTIVE
    mission_started = false
    mission_start_frame = 0
    mission_end_frame = 0
    mission_score = 0

    clear_attached_visuals()
    clear_gate()

    mod_storage_save("handoff_pending", "0")
end

local function apply_visual_scale(obj)
    obj_scale_xyz(obj, visual_scale, visual_scale, visual_scale)
end

-- ============================================================================
-- A7/A8 pickup definitions
-- ============================================================================

local PICKUPS = {
    {
        key = "COIN",
        label = "MONEDA",
        behavior = id_bhvYellowCoin,
        model = E_MODEL_YELLOW_COIN,
        threshold = 1.80,
        growth = 0.08,
        visualScale = 0.78,
        attachOffset = 3,
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
        visualScale = 0.78,
        attachOffset = 3,
        centerY = 0,
        animations = nil,
        animationIndex = 0,
    },
    {
        key = "GOOMBA",
        label = "GOOMBA",
        behavior = id_bhvGoomba,
        model = E_MODEL_GOOMBA,
        threshold = 1.80,
        growth = 0.35,
        visualScale = 0.88,
        attachOffset = 15,
        centerY = 30,
        animations = gObjectAnimations.goomba_seg8_anims_0801DA4C,
        animationIndex = 0,
    },
    {
        key = "BOBOMB",
        label = "BOB-OMB",
        behavior = id_bhvBobomb,
        model = E_MODEL_BLACK_BOBOMB,
        threshold = 2.70,
        growth = 0.50,
        visualScale = 0.86,
        attachOffset = 13,
        centerY = 25,
        animations = gObjectAnimations.bobomb_seg8_anims_0802396C,
        animationIndex = 0,
    },
}

-- ============================================================================
-- Rigid passive attachments
-- ============================================================================

local function ray_hits_before_target(ball, x, y, z)
    local dx = x - ball.oPosX
    local dy = y - ball.oPosY
    local dz = z - ball.oPosZ
    local target_dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    if target_dist < 2 then
        return false
    end

    local hit = collision_find_surface_on_ray(
        ball.oPosX, ball.oPosY, ball.oPosZ,
        dx, dy, dz,
        2.5
    )

    if hit == nil or hit.surface == nil then
        return false
    end

    local hit_dist = distance3(
        ball.oPosX, ball.oPosY, ball.oPosZ,
        hit.hitPos.x, hit.hitPos.y, hit.hitPos.z
    )

    return hit_dist < target_dist - 5
end

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

    -- Rigid body rule: update ONLY from ball rotation.
    local dyaw = ball.oFaceAngleYaw - data.lastYaw
    local dpitch = ball.oFaceAnglePitch - data.lastPitch

    data.dx, data.dy, data.dz = rotate_y(data.dx, data.dy, data.dz, dyaw)
    data.dx, data.dy, data.dz = rotate_x(data.dx, data.dy, data.dz, dpitch)
    data.dx, data.dy, data.dz = normalize3(data.dx, data.dy, data.dz)

    data.lastYaw = ball.oFaceAngleYaw
    data.lastPitch = ball.oFaceAnglePitch

    local r = ball_surface_radius() + data.attachOffset

    local x = ball.oPosX + data.dx * r
    local y = ball.oPosY + data.dy * r
    local z = ball.oPosZ + data.dz * r

    -- No per-object floor clamp. If terrain occludes the rigid attachment,
    -- hide it until the sphere rotates it back into visible space.
    set_object_visible(obj, not ray_hits_before_target(ball, x, y, z))

    obj.oPosX = x
    obj.oPosY = y
    obj.oPosZ = z

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
            animations = spec.animations,
            animationIndex = spec.animationIndex,
            initialized = false,
        }
    end
end

-- ============================================================================
-- Compact mode: logical mass != visual envelope
-- ============================================================================

local CLEARANCE_DIRS = {
    {  1.000, 0,  0.000 },
    { -1.000, 0,  0.000 },
    {  0.000, 0,  1.000 },
    {  0.000, 0, -1.000 },
    {  0.707, 0,  0.707 },
    { -0.707, 0,  0.707 },
    {  0.707, 0, -0.707 },
    { -0.707, 0, -0.707 },
    {  0.000, 1,  0.000 },
}

local function update_compact_target(ball)
    local desired_radius = logical_ball_radius()
    local ray_len = desired_radius + COMPACT_RAY_EXTRA
    local min_clearance = ray_len

    for _, dir in ipairs(CLEARANCE_DIRS) do
        local hit = collision_find_surface_on_ray(
            ball.oPosX, ball.oPosY, ball.oPosZ,
            dir[1] * ray_len,
            dir[2] * ray_len,
            dir[3] * ray_len,
            2.0
        )

        if hit ~= nil and hit.surface ~= nil then
            local d = distance3(
                ball.oPosX, ball.oPosY, ball.oPosZ,
                hit.hitPos.x, hit.hitPos.y, hit.hitPos.z
            )
            min_clearance = math.min(min_clearance, d)
        end
    end

    local allowed_radius = math.max(
        MODEL_BODY_RADIUS * MIN_COMPACT_SCALE,
        min_clearance - COMPACT_MARGIN
    )

    clearance_scale = allowed_radius / MODEL_BODY_RADIUS
    visual_target_scale = math.min(logical_scale, clearance_scale)
    visual_target_scale = math.max(visual_target_scale, MIN_COMPACT_SCALE)

    compact_active = visual_target_scale < logical_scale - 0.08
end

-- ============================================================================
-- Mission and portal
-- ============================================================================

local function mission_requirements_met()
    return counts.COIN >= M1_REQ_COINS
       and counts.GOOMBA >= M1_REQ_GOOMBAS
       and counts.BOBOMB >= M1_REQ_BOBOMBS
       and logical_scale >= M1_REQ_SCALE
end

local function calculate_mission_score()
    local elapsed_frames = math.max(mission_end_frame - mission_start_frame, 1)
    local elapsed_seconds = elapsed_frames / 30.0
    local time_bonus = math.max(0, 7000 - math.floor(elapsed_seconds * 22))

    return math.floor(
        counts.COIN * 50
        + counts.GOOMBA * 350
        + counts.BOBOMB * 800
        + logical_scale * 1000
        + time_bonus
    )
end

local function save_handoff()
    mod_storage_save("handoff_pending", "1")
    mod_storage_save("handoff_source", "SM64_BOB")
    mod_storage_save("handoff_target", M1_TARGET_WORLD)

    mod_storage_save_number("handoff_scale", logical_scale)
    mod_storage_save_integer("handoff_coins", counts.COIN)
    mod_storage_save_integer("handoff_goombas", counts.GOOMBA)
    mod_storage_save_integer("handoff_bobombs", counts.BOBOMB)
    mod_storage_save_integer("handoff_score", mission_score)
end

local function bhv_nexo_gate_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oInteractType = 0
    obj.oIntangibleTimer = -1
    cur_obj_become_intangible()
end

local function bhv_nexo_gate_loop(obj)
    if mission_state == MISSION_ACTIVE or not mission_started then
        obj_mark_for_deletion(obj)
        return
    end

    local floor_y = find_floor_height(
        mission_origin.x,
        mission_origin.y + 400,
        mission_origin.z
    )

    local y = mission_origin.y
    if floor_y > -10000 then
        y = floor_y + 125
    end

    obj.oPosX = mission_origin.x
    obj.oPosY = y
    obj.oPosZ = mission_origin.z

    obj.header.gfx.pos.x = obj.oPosX
    obj.header.gfx.pos.y = obj.oPosY
    obj.header.gfx.pos.z = obj.oPosZ

    obj.oFaceAngleYaw = obj.oFaceAngleYaw + 0x280
    obj.oFaceAnglePitch = obj.oFaceAnglePitch + 0x70

    local pulse = 2.15 + math.sin(get_global_timer() / 8.0) * 0.20
    obj_scale(obj, pulse)
end

id_bhvNexoGate = hook_behavior(
    nil,
    OBJ_LIST_UNIMPORTANT,
    true,
    bhv_nexo_gate_init,
    bhv_nexo_gate_loop
)

local function spawn_gate_if_needed()
    if mission_state ~= MISSION_RETURN or get_gate() ~= nil then
        return
    end

    spawn_non_sync_object(
        id_bhvNexoGate,
        E_MODEL_TRANSPARENT_STAR,
        mission_origin.x,
        mission_origin.y + 120,
        mission_origin.z,
        nil
    )
end

local function complete_mission()
    if mission_state ~= MISSION_RETURN then return end

    mission_state = MISSION_COMPLETE
    mission_end_frame = get_global_timer()
    mission_score = calculate_mission_score()

    if mission_score > mission_best_score then
        mission_best_score = mission_score
        mod_storage_save_integer("m1_best_score", mission_best_score)
    end

    save_handoff()

    print(
        "[NEXO] M1 COMPLETE score=" .. tostring(mission_score)
        .. " handoff=" .. M1_TARGET_WORLD
    )
end

local function update_mission(m)
    if not mission_started then
        mission_started = true
        mission_origin.x = m.pos.x
        mission_origin.y = m.pos.y
        mission_origin.z = m.pos.z
        mission_start_frame = get_global_timer()
        mod_storage_save("handoff_pending", "0")
    end

    if mission_state == MISSION_ACTIVE and mission_requirements_met() then
        mission_state = MISSION_RETURN
        spawn_gate_if_needed()
    end

    if mission_state == MISSION_RETURN then
        spawn_gate_if_needed()

        local gate = get_gate()
        if gate ~= nil then
            local dist = distance3(
                m.pos.x, m.pos.y, m.pos.z,
                gate.oPosX, gate.oPosY, gate.oPosZ
            )

            if dist <= M1_PORTAL_RADIUS then
                complete_mission()
            end
        end
    end
end

-- ============================================================================
-- Katamari absorber
-- ============================================================================

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
    update_logical_scale()

    absorb_label = spec.label .. " +" .. string.format("%.2f", spec.growth)
    absorb_flash = ABSORB_FLASH_FRAMES

    cur_obj_play_sound_2(SOUND_GENERAL_COIN)

    print(
        "[NEXO] Absorbed " .. spec.label
        .. " total=" .. tostring(absorbed_count)
        .. " logicalScale=" .. tostring(logical_scale)
    )
end

local function scan_pickup_type(ball, spec)
    local obj = obj_get_first_with_behavior_id(spec.behavior)
    local safety = 0

    -- Pickup volume follows the currently visible envelope to avoid
    -- vacuuming objects through walls while in compact mode.
    local pickup_radius = ball_surface_radius() + PICKUP_PADDING
    local warning_radius = pickup_radius + LOCK_WARNING_MARGIN

    while obj ~= nil and safety < 512 do
        safety = safety + 1
        local next_obj = obj_get_next_with_same_behavior_id(obj)

        local dist = dist_between_objects(ball, obj)

        if dist <= pickup_radius then
            if logical_scale + 0.001 >= spec.threshold then
                absorb_target(obj, ball, spec)
            else
                show_locked_feedback(spec)
            end
        elseif dist <= warning_radius and logical_scale + 0.001 < spec.threshold then
            show_locked_feedback(spec)
        end

        obj = next_obj
    end
end

local function scan_all_pickups(ball)
    if mission_state == MISSION_COMPLETE then
        return
    end

    for _, spec in ipairs(PICKUPS) do
        scan_pickup_type(ball, spec)
    end
end

local function bhv_nexo_ball_loop(obj)
    if visual_scale < visual_target_scale then
        visual_scale = math.min(
            visual_scale + (compact_active and COMPACT_SPEED or EXPAND_SPEED),
            visual_target_scale
        )
    elseif visual_scale > visual_target_scale then
        visual_scale = math.max(
            visual_scale - COMPACT_SPEED,
            visual_target_scale
        )
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

    spawn_non_sync_object(
        id_bhvNexoBall,
        E_MODEL_SPINY_BALL,
        m.pos.x,
        m.pos.y,
        m.pos.z,
        nil
    )

    last_ball_x = nil
    last_ball_z = nil

    print("[NEXO] M1 katamari spawned")
end

local function update_ball_from_mario(m, ball)
    local yaw = m.faceAngle.y

    local offset = math.min(112 + ball_surface_radius() * 0.25, 155)

    local x = m.pos.x + sins(yaw) * offset
    local z = m.pos.z + coss(yaw) * offset

    local floor_y = find_floor_height(x, m.pos.y + 450, z)
    local y = m.pos.y

    if floor_y > -10000 then
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

    -- Compute compact mode AFTER placing the visual center in the world.
    update_compact_target(ball)
end

-- ============================================================================
-- Mario / level hooks
-- ============================================================================

local function remove_runtime_objects_outside_mission()
    local ball = get_ball()
    if ball ~= nil then obj_mark_for_deletion(ball) end

    clear_attached_visuals()
    clear_gate()
end

local function mario_update(m)
    if m.playerIndex ~= 0 then
        return
    end

    if absorb_flash > 0 then absorb_flash = absorb_flash - 1 end
    if lock_flash > 0 then lock_flash = lock_flash - 1 end

    -- M1 is intentionally scoped to Bob-omb Battlefield.
    if gCurrCourseNum ~= COURSE_BOB then
        remove_runtime_objects_outside_mission()
        return
    end

    local ball = get_ball()

    if ball == nil then
        spawn_ball_for_mario(m)
        ball = get_ball()
        if ball == nil then return end
    end

    if (m.controller.buttonPressed & D_JPAD) ~= 0 then
        reset_progress()
        spawn_ball_for_mario(m)
        return
    end

    update_ball_from_mario(m, ball)
    update_mission(m)
end

local function on_level_init()
    reset_progress()
end

local function on_object_unload(obj)
    if obj ~= nil and obj._pointer ~= nil then
        attached_data[tostring(obj._pointer)] = nil
    end
end

-- ============================================================================
-- HUD
-- ============================================================================

local function render_check(x, y, done, label)
    if done then
        djui_hud_set_color(120, 255, 140, 255)
        djui_hud_print_text("[OK] " .. label, x, y, 0.21)
    else
        djui_hud_set_color(230, 230, 230, 255)
        djui_hud_print_text("[ ] " .. label, x, y, 0.21)
    end
end

local function on_hud_render()
    -- No project HUD in castle/hub yet.
    if gCurrCourseNum ~= COURSE_BOB then
        return
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)

    local x = 24
    local y = 24
    local width = 585
    local height = 220

    djui_hud_set_color(0, 0, 0, 178)
    djui_hud_render_rect(x - 8, y - 8, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(TITLE, x, y, 0.47)

    djui_hud_set_color(135, 255, 150, 255)
    djui_hud_print_text(STATUS, x, y + 25, 0.31)

    local compact_text = ""
    if compact_active then compact_text = " | COMPACT" end

    djui_hud_set_color(255, 230, 120, 255)
    djui_hud_print_text(
        "MASA: " .. string.format("%.2f", logical_scale)
        .. " | VIS: " .. string.format("%.2f", visual_scale)
        .. compact_text,
        x, y + 47, 0.22
    )

    djui_hud_set_color(200, 215, 255, 255)
    djui_hud_print_text(
        "M:" .. tostring(counts.COIN)
        .. " G:" .. tostring(counts.GOOMBA)
        .. " B:" .. tostring(counts.BOBOMB)
        .. " | OBJ:" .. tostring(absorbed_count),
        x, y + 66, 0.21
    )

    if mission_state == MISSION_ACTIVE then
        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text("CARGA REQUERIDA", x, y + 87, 0.23)

        render_check(x, y + 106, counts.COIN >= M1_REQ_COINS,
            tostring(M1_REQ_COINS) .. " monedas (" .. tostring(counts.COIN) .. ")")
        render_check(x, y + 123, counts.GOOMBA >= M1_REQ_GOOMBAS,
            tostring(M1_REQ_GOOMBAS) .. " Goombas (" .. tostring(counts.GOOMBA) .. ")")
        render_check(x, y + 140, counts.BOBOMB >= M1_REQ_BOBOMBS,
            tostring(M1_REQ_BOBOMBS) .. " Bob-ombs (" .. tostring(counts.BOBOMB) .. ")")
        render_check(x, y + 157, logical_scale >= M1_REQ_SCALE,
            "masa " .. string.format("%.2f", M1_REQ_SCALE)
            .. " (" .. string.format("%.2f", logical_scale) .. ")")

        djui_hud_set_color(180, 180, 180, 255)
        djui_hud_print_text(RESET_HINT, x, y + 184, 0.20)

    elseif mission_state == MISSION_RETURN then
        djui_hud_set_color(120, 255, 255, 255)
        djui_hud_print_text("CARGA COMPLETA", x, y + 92, 0.32)

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text("REGRESA AL NEXO GATE DEL INICIO", x, y + 120, 0.25)
        djui_hud_print_text("DESTINO SIGUIENTE: " .. M1_TARGET_WORLD, x, y + 145, 0.23)

        djui_hud_set_color(180, 180, 180, 255)
        djui_hud_print_text(
            "Tiempo: " .. format_seconds(get_global_timer() - mission_start_frame) .. " s",
            x, y + 172, 0.20
        )

    else
        djui_hud_set_color(120, 255, 160, 255)
        djui_hud_print_text("MISION COMPLETA", x, y + 91, 0.34)

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text("SCORE: " .. tostring(mission_score), x, y + 121, 0.26)
        djui_hud_print_text("BEST: " .. tostring(mission_best_score), x, y + 144, 0.22)

        djui_hud_set_color(140, 210, 255, 255)
        djui_hud_print_text(
            "HANDOFF PREPARADO -> " .. M1_TARGET_WORLD,
            x, y + 166, 0.22
        )
        djui_hud_print_text(
            "Tiempo: " .. format_seconds(mission_end_frame - mission_start_frame) .. " s",
            x, y + 186, 0.20
        )
    end

    if absorb_flash > 0 then
        djui_hud_set_color(120, 255, 120, 255)
        djui_hud_print_text(absorb_label, x + 330, y + 88, 0.23)
    elseif lock_flash > 0 then
        djui_hud_set_color(255, 150, 90, 255)
        djui_hud_print_text("BLOQUEADO: " .. lock_label, x + 300, y + 88, 0.20)
    end
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_ON_OBJECT_UNLOAD, on_object_unload)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

print("[NEXO] M1 vertical slice active: rigid attachments + compact mode + NEXO Gate")
