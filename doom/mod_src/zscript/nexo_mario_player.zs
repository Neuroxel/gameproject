class NexoMarioDoomPlayer : DoomPlayer
{
    // Avatar movement state. This is world-independent Mario identity state,
    // not M2 mission state.
    int NexoJumpChain;
    int NexoLastLandTick;
    bool NexoWasOnGround;
    bool NexoStompActive;

    // Directional traversal state.
    int NexoPrevForwardMove;
    int NexoPrevSideMove;
    int NexoWallKickCooldown;
    bool NexoDiveActive;
    int NexoSlideTicks;
    double NexoDiveAngle;

    // First-person Mario embodiment state.
    int NexoHandFireTics;
    int NexoHandFireDuration;
    bool NexoHandWasFiring;
    bool NexoFistLeftPunch;
    bool NexoNativeWeaponHidden;
    Vector2 NexoNativeWeaponScale;
    int NexoHandMotionKind;
    int NexoHandMotionTics;
    int NexoHandMotionDuration;

    Default
    {
        // Mario is a dedicated avatar, not a selectable DOOM skin. +NOSKIN is
        // also required for sound identity: GZDoom otherwise lets the active
        // skin override Player.SoundClass before resolving *usefail/*pain/etc.
        +NOSKIN
        Player.SoundClass "nexo_mario";
    }

    bool NexoCVarBool(Name key)
    {
        let cv = CVar.GetCVar(key);
        return cv != null && cv.GetBool();
    }

    bool NexoMovementEnabled()
    {
        return NexoCVarBool('nexo_handoff') && NexoCVarBool('nexo_mario_movement');
    }

    void NexoPlayMovementSound(String soundName)
    {
        if (!NexoCVarBool('nexo_mario_sfx')) return;
        if (player != null && (player.cheats & CF_PREDICTING)) return;
        A_StartSound(soundName, CHAN_BODY);
    }

    void NexoPlayJumpVoice(int jumpStage)
    {
        if (!NexoCVarBool('nexo_mario_sfx')) return;
        if (player != null && (player.cheats & CF_PREDICTING)) return;

        if (jumpStage <= 1)
        {
            // SM64 generic jump voice: random Yah / Wah / Hoo.
            int roll = random[NexoMarioJumpVoice](0, 2);
            if (roll == 0)
                A_StartSound("nexo/mario/jump1_yah", CHAN_BODY);
            else if (roll == 1)
                A_StartSound("nexo/mario/jump1_wah", CHAN_BODY);
            else
                A_StartSound("nexo/mario/jump1_hoo", CHAN_BODY);
            return;
        }

        if (jumpStage == 2)
        {
            // SM64 double jump has its own Hoo-hoo call.
            A_StartSound("nexo/mario/jump2_hoohoo", CHAN_BODY);
            return;
        }

        // SM64 triple jump selects from Yahoo / Waha / Yippee with a
        // 60/20/20 distribution.
        int tripleRoll = random[NexoMarioTripleVoice](0, 4);
        if (tripleRoll <= 2)
            A_StartSound("nexo/mario/jump3_yahoo", CHAN_BODY);
        else if (tripleRoll == 3)
            A_StartSound("nexo/mario/jump3_waha", CHAN_BODY);
        else
            A_StartSound("nexo/mario/jump3_yippee", CHAN_BODY);
    }

    bool NexoCanStand()
    {
        if (Pos.Z + FullHeight > ceilingz) return false;

        double savedHeight = Height;
        Height = FullHeight;
        bool fits = TryMove(Pos.XY, false, NULL);
        Height = savedHeight;
        return fits;
    }

    double NexoCeilingSafeLaunch(double desiredSpeed)
    {
        // Maximize the Mario jump while keeping a small head-clearance reserve.
        // GZDoom integrates Z first and then subtracts gravity each tic. For
        // constant gravity, a launch speed v rises approximately
        // v*(v+g)/(2g). Solve that inequality for the available headroom.
        double headroom = CeilingZ - (Pos.Z + FullHeight) - 5.0;
        if (headroom <= 0.0) return 0.0;

        double grav = GetGravity();
        if (grav <= 0.001) return desiredSpeed;

        double safeSpeed =
            (-grav + sqrt(grav * grav + 8.0 * grav * headroom)) * 0.5;

        return min(desiredSpeed, max(0.0, safeSpeed));
    }

    double NexoInputAngle()
    {
        if (player == null) return Angle;

        Vector2 input =
            AngleToVector(Angle, player.cmd.forwardmove / 32768.0)
            + AngleToVector(Angle + 90.0, player.cmd.sidemove / 32768.0);

        if (input.Length() < 0.05) return Angle;
        return VectorAngle(input.X, input.Y);
    }

    bool NexoDirectionReversed()
    {
        if (player == null) return false;

        int f = player.cmd.forwardmove;
        int s = player.cmd.sidemove;
        int threshold = 0x1800;

        bool forwardReverse =
            ((f > threshold && NexoPrevForwardMove < -threshold)
            || (f < -threshold && NexoPrevForwardMove > threshold));

        bool sideReverse =
            ((s > threshold && NexoPrevSideMove < -threshold)
            || (s < -threshold && NexoPrevSideMove > threshold));

        return forwardReverse || sideReverse;
    }

    bool NexoWallAhead(out double wallAngle)
    {
        wallAngle = NexoInputAngle();

        // MovePlayer runs immediately before CheckJump. GZDoom exposes
        // MovementBlockingLine specifically as the line that stopped the
        // actor's current XY movement, so wall-kick requires real collision
        // evidence instead of a speculative proximity trace.
        return MovementBlockingLine != null;
    }

    void NexoResetAirActions()
    {
        NexoStompActive = false;
        NexoDiveActive = false;
        NexoWallKickCooldown = 0;
    }

    void NexoSetHandMotion(int kind, int duration)
    {
        NexoHandMotionKind = kind;
        NexoHandMotionDuration = max(1, duration);
        NexoHandMotionTics = NexoHandMotionDuration;
    }

    void NexoRestoreNativeWeapon()
    {
        if (player == null || !NexoNativeWeaponHidden) return;

        let weaponPsp = player.FindPSprite(PSP_WEAPON);
        if (weaponPsp != null)
        {
            weaponPsp.scale = NexoNativeWeaponScale;
        }
        NexoNativeWeaponHidden = false;
    }

    void NexoSetNativeWeaponHidden(bool hidden)
    {
        if (player == null) return;

        let weaponPsp = player.FindPSprite(PSP_WEAPON);
        if (weaponPsp == null) return;

        if (hidden)
        {
            if (!NexoNativeWeaponHidden)
            {
                NexoNativeWeaponScale = weaponPsp.scale;
                NexoNativeWeaponHidden = true;
            }

            // PSprite.scale is directly exposed in GZDoom 4.14.2 ZScript.
            // Scaling the visual to zero hides only the native Fist artwork;
            // weapon state, attack timing and damage keep running normally.
            weaponPsp.scale = (0.0, 0.0);
        }
        else
        {
            NexoRestoreNativeWeapon();
        }
    }

    void NexoClearHandLayers()
    {
        if (player == null) return;

        NexoRestoreNativeWeapon();

        let back = player.FindPSprite(-2);
        if (back != null) back.SetState(null);

        let front = player.FindPSprite(2);
        if (front != null) front.SetState(null);

        NexoHandFireTics = 0;
        NexoHandFireDuration = 0;
        NexoHandWasFiring = false;
    }

    void NexoSetHandLayers(State backState, State frontState)
    {
        if (player == null || player.ReadyWeapon == null)
        {
            NexoClearHandLayers();
            return;
        }

        if (backState == null || frontState == null)
        {
            NexoClearHandLayers();
            return;
        }

        let back = player.FindPSprite(-2);
        if (back == null
            || back.CurState != backState
            || back.Caller != player.ReadyWeapon)
        {
            player.SetPSprite(-2, backState);
        }

        let front = player.FindPSprite(2);
        if (front == null
            || front.CurState != frontState
            || front.Caller != player.ReadyWeapon)
        {
            player.SetPSprite(2, frontState);
        }
    }

    void NexoUseHandPose(State backState, State frontState)
    {
        NexoSetHandLayers(backState, frontState);
    }

    bool NexoWeaponIsFiring(Weapon weapon)
    {
        if (player == null || weapon == null) return false;

        let psp = player.FindPSprite(PSP_WEAPON);
        if (psp == null || psp.CurState == null) return false;

        State fire = weapon.FindState('Fire');
        State hold = weapon.FindState('Hold');
        State altFire = weapon.FindState('AltFire');
        State altHold = weapon.FindState('AltHold');

        return
            (fire != null && InStateSequence(psp.CurState, fire))
            || (hold != null && InStateSequence(psp.CurState, hold))
            || (altFire != null && InStateSequence(psp.CurState, altFire))
            || (altHold != null && InStateSequence(psp.CurState, altHold));
    }

    bool NexoContinuousWeapon(Weapon weapon)
    {
        return weapon is "Chainsaw"
            || weapon is "Chaingun"
            || weapon is "PlasmaRifle"
            || weapon is "ID24Incinerator";
    }

    int NexoWeaponFireDuration(Weapon weapon)
    {
        if (weapon is "Fist") return 8;
        if (weapon is "Chainsaw") return 3;
        if (weapon is "Pistol") return 5;
        if (weapon is "Shotgun") return 7;
        if (weapon is "SuperShotgun") return 9;
        if (weapon is "Chaingun") return 3;
        if (weapon is "RocketLauncher") return 7;
        if (weapon is "PlasmaRifle" || weapon is "ID24Incinerator") return 3;
        if (weapon is "BFG9000" || weapon is "ID24CalamityBlade") return 9;
        return 5;
    }

    void NexoAnimateFirstPersonHands(Weapon weapon)
    {
        if (player == null || weapon == null) return;

        let back = player.FindPSprite(-2);
        let front = player.FindPSprite(2);
        if (back == null || front == null) return;

        // Overlay sprites already inherit native weapon raise/lower position and
        // bob through PSPF_ADDWEAPON/PSPF_ADDBOB. These values are therefore
        // animation deltas only.
        back.x = 0.0;
        back.y = 0.0;
        back.rotation = 0.0;
        front.x = 0.0;
        front.y = 0.0;
        front.rotation = 0.0;

        bool attackDown =
            (player.cmd.buttons & (BT_ATTACK | BT_ALTATTACK)) != 0;
        bool attackRising =
            attackDown
            && !(player.oldbuttons & (BT_ATTACK | BT_ALTATTACK));

        // Weapon-state detection is authoritative; fresh attack input is a
        // one-tic fallback so the hand response starts immediately even when
        // the destination weapon changes PSprite state later in the tick.
        bool firing = NexoWeaponIsFiring(weapon) || attackRising;

        if (firing && !NexoHandWasFiring)
        {
            NexoHandFireDuration = NexoWeaponFireDuration(weapon);
            NexoHandFireTics = NexoHandFireDuration;

            if (weapon is "Fist")
            {
                NexoFistLeftPunch = !NexoFistLeftPunch;
            }
        }
        else if (firing
            && NexoContinuousWeapon(weapon)
            && NexoHandFireTics <= 0)
        {
            NexoHandFireDuration = NexoWeaponFireDuration(weapon);
            NexoHandFireTics = NexoHandFireDuration;
        }

        if (NexoHandFireTics > 0 && NexoHandFireDuration > 0)
        {
            double half = max(1.0, NexoHandFireDuration * 0.5);
            double pulse =
                1.0 - abs(NexoHandFireTics - half) / half;
            pulse = clamp(pulse, 0.0, 1.0);

            if (weapon is "Fist")
            {
                // Two Mario fists remain low in the ready pose. Each attack
                // alternates which glove drives toward the center/up.
                if (NexoFistLeftPunch)
                {
                    back.x = 23.0 * pulse;
                    back.y = -19.0 * pulse;
                    back.rotation = -10.0 * pulse;
                    front.x = 2.0 * pulse;
                    front.y = 2.0 * pulse;
                }
                else
                {
                    front.x = -23.0 * pulse;
                    front.y = -19.0 * pulse;
                    front.rotation = 10.0 * pulse;
                    back.x = -2.0 * pulse;
                    back.y = 2.0 * pulse;
                }
            }
            else if (weapon is "Chainsaw")
            {
                double jitter = ((Level.maptime & 1) != 0) ? 1.6 : -1.6;
                back.x += jitter * pulse;
                front.x -= jitter * pulse;
                back.y -= 1.5 * pulse;
                front.y += 1.0 * pulse;
            }
            else if (weapon is "Pistol")
            {
                back.y -= 2.0 * pulse;
                front.y -= 5.0 * pulse;
                front.rotation = 3.0 * pulse;
            }
            else if (weapon is "Shotgun")
            {
                back.y -= 4.0 * pulse;
                front.y -= 7.0 * pulse;
                back.rotation = -2.0 * pulse;
                front.rotation = 3.5 * pulse;
            }
            else if (weapon is "SuperShotgun")
            {
                back.y -= 5.0 * pulse;
                front.y -= 8.5 * pulse;
                back.rotation = -3.0 * pulse;
                front.rotation = 4.0 * pulse;
            }
            else if (weapon is "Chaingun")
            {
                double jitter = ((Level.maptime & 1) != 0) ? 1.8 : -1.8;
                back.x += jitter * pulse;
                front.x -= jitter * pulse;
                back.y -= 2.0 * pulse;
                front.y -= 3.0 * pulse;
            }
            else if (weapon is "RocketLauncher")
            {
                back.y += 3.5 * pulse;
                front.y += 5.0 * pulse;
                back.rotation = 2.0 * pulse;
                front.rotation = -3.0 * pulse;
            }
            else if (weapon is "PlasmaRifle" || weapon is "ID24Incinerator")
            {
                double jitter = ((Level.maptime & 1) != 0) ? 1.2 : -1.2;
                back.x += jitter * pulse;
                front.x -= jitter * pulse;
                back.y -= 2.0 * pulse;
                front.y -= 3.0 * pulse;
            }
            else if (weapon is "BFG9000" || weapon is "ID24CalamityBlade")
            {
                back.y += 4.0 * pulse;
                front.y += 5.5 * pulse;
                back.rotation = 2.0 * pulse;
                front.rotation = -2.0 * pulse;
            }
        }

        // Movement presentation: convey Mario's traversal through hands/weapon
        // without rolling the first-person camera through a somersault.
        if (NexoHandMotionTics > 0 && NexoHandMotionDuration > 0)
        {
            double motion =
                NexoHandMotionTics / (NexoHandMotionDuration * 1.0);

            if (NexoHandMotionKind == 1)       // backflip
            {
                back.y -= 5.0 * motion;
                front.y -= 5.0 * motion;
                back.rotation -= 5.0 * motion;
                front.rotation += 5.0 * motion;
            }
            else if (NexoHandMotionKind == 2)  // side flip
            {
                back.x += 4.0 * motion;
                front.x += 4.0 * motion;
                back.rotation -= 3.0 * motion;
                front.rotation -= 3.0 * motion;
            }
            else if (NexoHandMotionKind == 3)  // wall kick
            {
                back.x -= 5.0 * motion;
                front.x -= 5.0 * motion;
                back.y -= 2.0 * motion;
                front.y -= 2.0 * motion;
            }
            else if (NexoHandMotionKind == 4)  // dive
            {
                back.y += 7.0 * motion;
                front.y += 7.0 * motion;
                back.rotation -= 2.0 * motion;
                front.rotation += 2.0 * motion;
            }
            else if (NexoHandMotionKind == 5)  // stomp
            {
                back.y -= 7.0 * motion;
                front.y -= 7.0 * motion;
            }
            else if (NexoHandMotionKind == 6)  // long jump
            {
                back.y += 3.0 * motion;
                front.y += 3.0 * motion;
            }

            NexoHandMotionTics--;
            if (NexoHandMotionTics <= 0)
            {
                NexoHandMotionKind = 0;
                NexoHandMotionDuration = 0;
            }
        }

        if (NexoHandFireTics > 0)
        {
            NexoHandFireTics--;
        }

        NexoHandWasFiring = firing;
    }

    void NexoUpdateFirstPersonHands()
    {
        if (player == null
            || !NexoCVarBool('nexo_handoff')
            || !NexoCVarBool('nexo_mario_hands_ready')
            || player.ReadyWeapon == null)
        {
            NexoClearHandLayers();
            return;
        }

        let handStates = GetDefaultByType("NexoMarioHandStates");
        if (handStates == null)
        {
            NexoClearHandLayers();
            return;
        }

        let weapon = player.ReadyWeapon;

        if (weapon is "Fist")
        {
            NexoUseHandPose(
                handStates.FindState('FistBack'),
                handStates.FindState('FistFront')
            );

            // The native Fist sprite contains the destination marine's brown
            // hand. Hide that presentation layer while keeping all native Fist
            // mechanics/damage/state logic alive underneath.
            NexoSetNativeWeaponHidden(true);
        }
        else
        {
            NexoSetNativeWeaponHidden(false);

            if (weapon is "Chainsaw")
            {
                NexoUseHandPose(
                    handStates.FindState('ChainsawBack'),
                    handStates.FindState('ChainsawFront')
                );
            }
            else if (weapon is "Pistol")
            {
                NexoUseHandPose(
                    handStates.FindState('PistolBack'),
                    handStates.FindState('PistolFront')
                );
            }
            else if (weapon is "SuperShotgun")
            {
                NexoUseHandPose(
                    handStates.FindState('SuperShotgunBack'),
                    handStates.FindState('SuperShotgunFront')
                );
            }
            else if (weapon is "Shotgun")
            {
                NexoUseHandPose(
                    handStates.FindState('ShotgunBack'),
                    handStates.FindState('ShotgunFront')
                );
            }
            else if (weapon is "Chaingun")
            {
                NexoUseHandPose(
                    handStates.FindState('ChaingunBack'),
                    handStates.FindState('ChaingunFront')
                );
            }
            else if (weapon is "RocketLauncher")
            {
                NexoUseHandPose(
                    handStates.FindState('RocketBack'),
                    handStates.FindState('RocketFront')
                );
            }
            else if (weapon is "PlasmaRifle" || weapon is "ID24Incinerator")
            {
                NexoUseHandPose(
                    handStates.FindState('PlasmaBack'),
                    handStates.FindState('PlasmaFront')
                );
            }
            else if (weapon is "BFG9000" || weapon is "ID24CalamityBlade")
            {
                NexoUseHandPose(
                    handStates.FindState('BFGBack'),
                    handStates.FindState('BFGFront')
                );
            }
            else
            {
                // Unknown/mod weapon: never paste a misleading generic grip.
                NexoClearHandLayers();
                return;
            }
        }

        NexoAnimateFirstPersonHands(weapon);
    }

    override void BeginPlay()
    {
        Super.BeginPlay();

        NexoJumpChain = 0;
        NexoLastLandTick = -100000;
        NexoWasOnGround = true;
        NexoStompActive = false;

        NexoPrevForwardMove = 0;
        NexoPrevSideMove = 0;
        NexoWallKickCooldown = 0;
        NexoDiveActive = false;
        NexoSlideTicks = 0;
        NexoDiveAngle = Angle;

        NexoHandFireTics = 0;
        NexoHandFireDuration = 0;
        NexoHandWasFiring = false;
        NexoFistLeftPunch = false;
        NexoNativeWeaponHidden = false;
        NexoNativeWeaponScale = (1.0, 1.0);
        NexoHandMotionKind = 0;
        NexoHandMotionTics = 0;
        NexoHandMotionDuration = 0;
    }

    override void PlayerThink()
    {
        Super.PlayerThink();

        if (player == null) return;

        // Hand overlays are presentation-only and remain dormant until a
        // validated local multi-weapon grip pack sets the readiness gate.
        NexoUpdateFirstPersonHands();

        bool onGroundNow = player.onground;

        if (NexoWallKickCooldown > 0)
        {
            NexoWallKickCooldown--;
        }

        if (onGroundNow && !NexoWasOnGround)
        {
            NexoLastLandTick = Level.maptime;

            // DOOM normally holds jumpTics after a jump. Mario's chained jumps
            // require a fresh button press, so clear the inherited cooldown as
            // soon as a real landing is confirmed.
            player.jumpTics = 0;

            if (NexoDiveActive)
            {
                NexoSlideTicks = 14;
            }

            NexoResetAirActions();
        }

        // Mario triple-jump timing: enough time to release and freshly press
        // Jump after landing, but standing around cancels the chain.
        if (onGroundNow
            && NexoJumpChain > 0
            && NexoLastLandTick > -100000
            && Level.maptime - NexoLastLandTick > 28)
        {
            NexoJumpChain = 0;
        }

        // Dive landing becomes a short ground slide. Keep it conservative:
        // no slope exploit, no infinite acceleration and no forced camera roll.
        if (onGroundNow && NexoSlideTicks > 0)
        {
            NexoSlideTicks--;
            Thrust(0.28, NexoDiveAngle);
        }
        else if (!onGroundNow && NexoSlideTicks > 0)
        {
            NexoSlideTicks = 0;
        }

        NexoWasOnGround = onGroundNow;
        NexoPrevForwardMove = player.cmd.forwardmove;
        NexoPrevSideMove = player.cmd.sidemove;
    }

    override void CheckJump()
    {
        let p = player;

        if (p == null || !NexoMovementEnabled())
        {
            Super.CheckJump();
            return;
        }

        bool jumpDown = (p.cmd.buttons & BT_JUMP) != 0;
        bool jumpRising = jumpDown && !(p.oldbuttons & BT_JUMP);

        // Mario-style ground jumps require a fresh press. This prevents held
        // Jump or rapid airborne button spam from generating extra jumps/audio.
        if (!jumpDown)
        {
            return;
        }

        bool dryGroundJump =
            p.onground
            && waterlevel < 2
            && !bNoGravity
            && level.IsJumpingAllowed()
            && p.jumpTics == 0;

        bool crouched = p.crouchfactor < 0.95 || p.crouchoffset != 0;
        double planarSpeed2 = Vel.X * Vel.X + Vel.Y * Vel.Y;
        bool movingIntent =
            abs(p.cmd.forwardmove) + abs(p.cmd.sidemove) >= 0x1800;
        bool forwardRun =
            p.cmd.forwardmove >= 0x1800 && planarSpeed2 >= 4.0;

        // WALL KICK / WALL JUMP
        // SM64 uses ~62 vs a normal-jump base of ~42: preserve that strong
        // distinction, but cap it to the current ceiling headroom.
        if (!p.onground
            && jumpRising
            && waterlevel < 2
            && !bNoGravity
            && NexoWallKickCooldown <= 0)
        {
            double wallAngle;
            if (NexoWallAhead(wallAngle))
            {
                double baseJump = JumpZ * 35 / TICRATE;
                double target = NexoCeilingSafeLaunch(baseJump * (62.0 / 42.0));

                Vel.X *= 0.25;
                Vel.Y *= 0.25;
                Vel.Z = max(Vel.Z, target);
                Thrust(6.5, wallAngle + 180.0);

                NexoJumpChain = 0;
                NexoStompActive = false;
                NexoDiveActive = false;
                NexoSlideTicks = 0;
                NexoWallKickCooldown = 9;
                NexoSetHandMotion(3, 8);

                NexoPlayMovementSound("nexo/mario/wallkick");
                return;
            }
        }

        // Crouch + jump while moving = long jump.
        // Crouch + jump from near-standstill = backflip.
        if (dryGroundJump && jumpRising && crouched && NexoCanStand())
        {
            double baseJump = JumpZ * 35 / TICRATE;

            p.Uncrouch();
            NexoJumpChain = 0;
            NexoStompActive = false;
            NexoDiveActive = false;
            NexoSlideTicks = 0;

            if (forwardRun)
            {
                // SM64 long jump vertical ratio is ~30/42, with horizontal
                // velocity doing most of the work.
                Vel.Z += NexoCeilingSafeLaunch(baseJump * (30.0 / 42.0));
                Thrust(7.5, Angle);
                NexoSetHandMotion(6, 9);
                NexoPlayMovementSound("nexo/mario/longjump");
            }
            else
            {
                // SM64 backflip ratio is ~62/42. No literal 360° FPS camera
                // rotation: hands/body communicate the somersault instead.
                Vel.Z += NexoCeilingSafeLaunch(baseJump * (62.0 / 42.0));
                Thrust(5.0, Angle + 180.0);
                NexoSetHandMotion(1, 12);
                NexoPlayMovementSound("nexo/mario/backflip");
            }

            bOnMobj = false;
            p.onground = false;
            p.jumpTics = -1;
            return;
        }

        // SIDE FLIP / TURNAROUND JUMP
        // SM64 uses the same ~62/42 vertical family as the backflip.
        if (dryGroundJump
            && jumpRising
            && !crouched
            && NexoDirectionReversed())
        {
            double baseJump = JumpZ * 35 / TICRATE;
            double jumpAngle = NexoInputAngle();

            Vel.X *= 0.45;
            Vel.Y *= 0.45;
            Vel.Z += NexoCeilingSafeLaunch(baseJump * (62.0 / 42.0));
            Thrust(5.5, jumpAngle);

            bOnMobj = false;
            p.onground = false;
            p.jumpTics = -1;

            NexoJumpChain = 0;
            NexoStompActive = false;
            NexoDiveActive = false;
            NexoSlideTicks = 0;
            NexoSetHandMotion(2, 10);

            NexoPlayMovementSound("nexo/mario/sideflip");
            return;
        }

        // NORMAL / DOUBLE / TRIPLE JUMP
        if (dryGroundJump && !crouched)
        {
            if (!jumpRising)
            {
                // Do not let the base player auto-hop from a held button.
                return;
            }

            int nextJump = 1;

            if (movingIntent
                && NexoJumpChain > 0
                && NexoJumpChain < 3
                && NexoLastLandTick > -100000
                && Level.maptime - NexoLastLandTick <= 28)
            {
                nextJump = NexoJumpChain + 1;
            }

            // SM64 source values are approximately:
            // normal 42, double 52, triple 69.
            // Use those velocity ratios, then dynamically clamp to the actual
            // current ceiling instead of globally flattening Mario's jumps.
            double ratio = 1.0;
            if (nextJump == 2) ratio = 52.0 / 42.0;
            else if (nextJump == 3) ratio = 69.0 / 42.0;

            double savedJumpZ = JumpZ;
            double oldVelZ = Vel.Z;
            double baseJump = savedJumpZ * 35 / TICRATE;
            double desiredLaunch = baseJump * ratio;
            double safeLaunch = NexoCeilingSafeLaunch(desiredLaunch);

            JumpZ = safeLaunch * TICRATE / 35.0;
            Super.CheckJump();
            JumpZ = savedJumpZ;

            bool jumped = p.jumpTics == -1 && Vel.Z > oldVelZ;
            if (jumped)
            {
                NexoJumpChain = nextJump;
                NexoLastLandTick = -100000;
                NexoStompActive = false;
                NexoDiveActive = false;
                NexoSlideTicks = 0;

                NexoPlayJumpVoice(nextJump);
            }
            return;
        }

        // Preserve swimming/flying/native special jump behavior.
        Super.CheckJump();
    }

    override void CheckCrouch(bool totallyfrozen)
    {
        let p = player;

        if (p != null && NexoMovementEnabled())
        {
            bool crouchDown = (p.cmd.buttons & BT_CROUCH) != 0;
            bool crouchRising = crouchDown && !(p.oldbuttons & BT_CROUCH);
            bool airborne = !p.onground || Pos.Z > floorz + 1.0;
            bool forwardDive =
                p.cmd.forwardmove >= 0x1800
                && (Vel.X * Vel.X + Vel.Y * Vel.Y) >= 2.0;

            if (!totallyfrozen
                && p.health > 0
                && crouchRising
                && airborne
                && waterlevel < 2
                && !bNoGravity)
            {
                p.cmd.buttons &= ~BT_CROUCH;
                p.Uncrouch();
                NexoJumpChain = 0;

                // AIR DIVE: forward + fresh crouch in air.
                if (forwardDive)
                {
                    NexoDiveAngle = NexoInputAngle();
                    Vel.X *= 0.45;
                    Vel.Y *= 0.45;
                    Thrust(9.0, NexoDiveAngle);
                    if (Vel.Z > -3.0) Vel.Z = -3.0;

                    NexoDiveActive = true;
                    NexoStompActive = false;
                    NexoSlideTicks = 0;
                    NexoSetHandMotion(4, 10);

                    NexoPlayMovementSound("nexo/mario/dive");
                    return;
                }

                // GROUND POUND / STOMP: fresh crouch in air without a strong
                // forward dive request.
                if (!NexoStompActive)
                {
                    Vel.X *= 0.35;
                    Vel.Y *= 0.35;
                    if (Vel.Z > -14.0) Vel.Z = -14.0;

                    NexoStompActive = true;
                    NexoDiveActive = false;
                    NexoSlideTicks = 0;
                    NexoSetHandMotion(5, 8);

                    NexoPlayMovementSound("nexo/mario/stomp");
                    return;
                }
            }
        }

        Super.CheckCrouch(totallyfrozen);
    }
}
