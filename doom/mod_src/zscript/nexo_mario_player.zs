class NexoMarioDoomPlayer : DoomPlayer
{
    // MARIOMOVE-1 state. This is avatar state, not M2 mission state.
    int NexoJumpChain;
    int NexoLastLandTick;
    bool NexoWasOnGround;
    bool NexoStompActive;

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

    override void BeginPlay()
    {
        Super.BeginPlay();

        NexoJumpChain = 0;
        NexoLastLandTick = -100000;
        NexoWasOnGround = true;
        NexoStompActive = false;
    }

    override void PlayerThink()
    {
        Super.PlayerThink();

        if (player == null) return;

        bool onGroundNow = player.onground;

        if (onGroundNow && !NexoWasOnGround)
        {
            NexoLastLandTick = Level.maptime;
            NexoStompActive = false;
        }

        // A triple-jump chain must be continued promptly after landing.
        // Staying grounded breaks the chain and prevents infinite bunny-hop
        // escalation.
        if (onGroundNow
            && NexoJumpChain > 0
            && NexoLastLandTick > -100000
            && Level.maptime - NexoLastLandTick > 14)
        {
            NexoJumpChain = 0;
        }

        NexoWasOnGround = onGroundNow;
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

        if (!jumpDown)
        {
            Super.CheckJump();
            return;
        }

        // MovePlayer() runs before CheckJump() and refreshes p.onground.
        if (p.onground && !NexoWasOnGround)
        {
            NexoLastLandTick = Level.maptime;
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

        // Crouch + jump while moving = long jump.
        // Crouch + jump from near-standstill = backflip.
        // Both are deliberately moderate compared with SM64 so DOOM geometry
        // and combat remain authoritative.
        if (dryGroundJump && jumpRising && crouched && NexoCanStand())
        {
            double baseJump = JumpZ * 35 / TICRATE;

            p.Uncrouch();
            NexoJumpChain = 0;
            NexoStompActive = false;

            if (forwardRun)
            {
                Vel.Z += baseJump * 0.78;
                Thrust(7.5, Angle);
                NexoPlayMovementSound("nexo/mario/longjump");
            }
            else
            {
                Vel.Z += baseJump * 1.18;
                Thrust(5.0, Angle + 180.0);
                NexoPlayMovementSound("nexo/mario/backflip");
            }

            bOnMobj = false;
            p.onground = false;
            p.jumpTics = -1;
            return;
        }

        // Normal jump / triple-jump chain. The engine still performs the
        // actual legality check and movement; NEXO only adjusts JumpZ for
        // the one confirmed jump attempt.
        if (dryGroundJump && !crouched)
        {
            int nextJump = 1;

            if (jumpRising
                && movingIntent
                && NexoJumpChain > 0
                && NexoJumpChain < 3
                && NexoLastLandTick > -100000
                && Level.maptime - NexoLastLandTick <= 14)
            {
                nextJump = NexoJumpChain + 1;
            }

            double factor = 1.0;
            if (nextJump == 2) factor = 1.08;
            else if (nextJump == 3) factor = 1.18;

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

                if (nextJump == 3)
                    NexoPlayMovementSound("nexo/mario/jump3");
                else if (nextJump == 2)
                    NexoPlayMovementSound("nexo/mario/jump2");
                else
                    NexoPlayMovementSound("nexo/mario/jump");
            }
            return;
        }

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

            // Air + fresh crouch press = Mario ground pound/stomp.
            // It is one activation per airborne cycle and intentionally does
            // not add radial damage yet; first prove traversal and map safety.
            if (!totallyfrozen
                && p.health > 0
                && crouchRising
                && airborne
                && !NexoStompActive
                && waterlevel < 2
                && !bNoGravity)
            {
                p.cmd.buttons &= ~BT_CROUCH;
                p.Uncrouch();

                Vel.X *= 0.35;
                Vel.Y *= 0.35;
                if (Vel.Z > -14.0) Vel.Z = -14.0;

                NexoStompActive = true;
                NexoJumpChain = 0;
                NexoPlayMovementSound("nexo/mario/stomp");
                return;
            }
        }

        Super.CheckCrouch(totallyfrozen);
    }
}
