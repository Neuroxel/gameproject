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

    Default
    {
        // Give this avatar its own player-sound namespace. This prevents
        // destination marine vocals from leaking underneath Mario.
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

    bool NexoCanStand()
    {
        if (Pos.Z + FullHeight > ceilingz) return false;

        double savedHeight = Height;
        Height = FullHeight;
        bool fits = TryMove(Pos.XY, false, NULL);
        Height = savedHeight;
        return fits;
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

    void NexoClearHandLayers()
    {
        if (player == null) return;

        let back = player.FindPSprite(-2);
        if (back != null) back.SetState(null);

        let front = player.FindPSprite(2);
        if (front != null) front.SetState(null);
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
        }
        else if (weapon is "Chainsaw")
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
        }
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

            // DOOM normally holds jumpTics for >18 tics after a jump. Mario's
            // chained jumps require a fresh button press, so the long engine
            // cooldown is unnecessary once landing is confirmed.
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
            && Level.maptime - NexoLastLandTick > 24)
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
        // Fresh Jump while airborne and actually contacting/approaching a wall.
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

                Vel.X *= 0.25;
                Vel.Y *= 0.25;
                Vel.Z = max(Vel.Z, baseJump * 1.12);
                Thrust(6.5, wallAngle + 180.0);

                NexoJumpChain = 0;
                NexoStompActive = false;
                NexoDiveActive = false;
                NexoSlideTicks = 0;
                NexoWallKickCooldown = 9;

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
                Vel.Z += baseJump * 0.78;
                Thrust(7.5, Angle);
                NexoPlayMovementSound("nexo/mario/longjump");
            }
            else
            {
                // SM64's backflip is distinctly higher. Do not rotate the
                // first-person camera 360°; visual rotation belongs to the
                // future hands/body animation layer.
                Vel.Z += baseJump * 1.35;
                Thrust(5.0, Angle + 180.0);
                NexoPlayMovementSound("nexo/mario/backflip");
            }

            bOnMobj = false;
            p.onground = false;
            p.jumpTics = -1;
            return;
        }

        // SIDE FLIP / TURNAROUND JUMP
        // A strong direction reversal immediately followed by a fresh jump.
        if (dryGroundJump
            && jumpRising
            && !crouched
            && NexoDirectionReversed())
        {
            double baseJump = JumpZ * 35 / TICRATE;
            double jumpAngle = NexoInputAngle();

            Vel.X *= 0.45;
            Vel.Y *= 0.45;
            Vel.Z += baseJump * 1.22;
            Thrust(5.5, jumpAngle);

            bOnMobj = false;
            p.onground = false;
            p.jumpTics = -1;

            NexoJumpChain = 0;
            NexoStompActive = false;
            NexoDiveActive = false;
            NexoSlideTicks = 0;

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
                && Level.maptime - NexoLastLandTick <= 24)
            {
                nextJump = NexoJumpChain + 1;
            }

            double factor = 1.0;
            if (nextJump == 2) factor = 1.10;
            else if (nextJump == 3) factor = 1.24;

            double savedJumpZ = JumpZ;
            double oldVelZ = Vel.Z;
            JumpZ = savedJumpZ * factor;

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

                if (nextJump == 3)
                    NexoPlayMovementSound("nexo/mario/jump3");
                else if (nextJump == 2)
                    NexoPlayMovementSound("nexo/mario/jump2");
                else
                    NexoPlayMovementSound("nexo/mario/jump");
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

                    NexoPlayMovementSound("nexo/mario/stomp");
                    return;
                }
            }
        }

        Super.CheckCrouch(totallyfrozen);
    }
}
