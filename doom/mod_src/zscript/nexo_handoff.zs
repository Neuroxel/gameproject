class NexoHandoffHandler : EventHandler
{
    bool Applied;
    bool InM2Map;
    bool IdentityActive;

    // Perspective adapter state.
    int PerspectiveTicks;
    int PerspectivePlayer;
    bool PerspectiveBodyVisible;

    // Mario identity/audio state.
    int LastButtons;
    int LastHealth;
    int HurtCooldown;

    // M2 — STABILIZE THE BREACH
    int M2Kills;
    int M2Goal;
    bool M2Complete;
    int M2Score;

    // Inherited state from M1.
    int Coins;
    int Goombas;
    int Bobombs;
    int InheritedScore;
    double Mass;

    int CVarInt(Name key)
    {
        let cv = CVar.GetCVar(key);
        if (cv == null) return 0;
        return cv.GetInt();
    }

    double CVarFloat(Name key)
    {
        let cv = CVar.GetCVar(key);
        if (cv == null) return 0.0;
        return cv.GetFloat();
    }

    bool CVarBool(Name key)
    {
        let cv = CVar.GetCVar(key);
        if (cv == null) return false;
        return cv.GetBool();
    }

    void PrintMission(String text, double duration = 4.0)
    {
        let pawn = players[consoleplayer].mo;
        if (pawn != null)
        {
            pawn.A_PrintBold(text, duration);
        }
    }

    void PlayMarioJump(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        pawn.A_StartSound("nexo/mario/jump", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
    }

    void PlayMarioUse(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        pawn.A_StartSound("nexo/mario/use", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
    }

    void PlayMarioHurt(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        pawn.A_StartSound("nexo/mario/hurt", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
    }

    void PlayMarioDeath(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        pawn.A_StartSound("nexo/mario/death", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
    }

    void PlayMarioPortal(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        pawn.A_StartSound("nexo/mario/portal", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
    }

    void PlayMarioCelebrate(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        pawn.A_StartSound("nexo/mario/celebrate", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
    }

    void BeginPerspectiveTransition(int playerNum)
    {
        if (!CVarBool('nexo_perspective_transition')) return;

        PerspectivePlayer = playerNum;
        PerspectiveTicks = 35;
        PerspectiveBodyVisible = false;

        // We only reveal a third-person body when an actual Mario body/skin
        // has been imported locally. Until then we preserve first-person DOOM
        // rather than pretending the Doom marine proxy is Mario.
        if (CVarBool('nexo_avatar_body_ready'))
        {
            players[playerNum].cheats |= CF_CHASECAM;
            players[playerNum].cheats |= CF_FROZEN;
            PerspectiveBodyVisible = true;
        }

        let pawn = players[playerNum].mo;
        if (pawn != null)
        {
            pawn.A_PrintBold(
                PerspectiveBodyVisible
                    ? "NEXO PERSPECTIVE SYNC\n3P AVATAR -> 1P DOOM"
                    : "NEXO PERSPECTIVE SYNC\nMARIO IDENTITY -> 1P DOOM",
                2.0
            );
        }
    }

    void EndPerspectiveTransition()
    {
        if (PerspectivePlayer < 0 || PerspectivePlayer >= MAXPLAYERS) return;

        if (PerspectiveBodyVisible)
        {
            players[PerspectivePlayer].cheats &= ~CF_CHASECAM;
            players[PerspectivePlayer].cheats &= ~CF_FROZEN;
        }

        PerspectiveTicks = 0;
        PerspectiveBodyVisible = false;
    }

    override void WorldLoaded(WorldEvent e)
    {
        InM2Map = Level.MapName ~== "MAP01";
        IdentityActive = CVarBool('nexo_handoff');

        // M2 belongs only to the arrival map. Once the player crosses the
        // semantic gate into MAP02, the original SM64 handoff must not be
        // applied again.
        if (!InM2Map)
        {
            Applied = false;
        }

        PerspectivePlayer = -1;
        PerspectiveTicks = 0;
        PerspectiveBodyVisible = false;
        LastButtons = 0;
        LastHealth = 0;
        HurtCooldown = 0;
    }

    override void PlayerEntered(PlayerEvent e)
    {
        let pawn = players[e.PlayerNumber].mo;

        // Mario's identity is world-independent inside the DOOM adapter.
        // M2 itself is still restricted to MAP01.
        if (IdentityActive && pawn != null)
        {
            // Cross-engine camera normalization: never inherit a stale/extreme
            // pitch into the first-person destination. The controller remains
            // fully live immediately after this one-time center operation.
            pawn.Pitch = 0.0;

            LastHealth = pawn.health;
            LastButtons = players[e.PlayerNumber].cmd.buttons;

            if (InM2Map)
            {
                if (CVarBool('nexo_mario_sfx'))
                {
                    Console.Printf("[NEXO] Mario portal cue requested: nexo/mario/portal\n");
                }
                PlayMarioPortal(pawn);
                BeginPerspectiveTransition(e.PlayerNumber);
            }
        }

        if (!InM2Map) return;
        if (Applied) return;
        if (!CVarBool('nexo_handoff')) return;
        if (pawn == null) return;

        Coins = CVarInt('nexo_coins');
        Goombas = CVarInt('nexo_goombas');
        Bobombs = CVarInt('nexo_bobombs');
        InheritedScore = CVarInt('nexo_score');
        Mass = CVarFloat('nexo_mass');

        M2Kills = 0;
        M2Goal = 8;
        M2Complete = false;
        M2Score = InheritedScore;

        // First cross-world semantic mapping:
        // coins -> armor, Goombas -> biomass/health, Bob-ombs -> explosives,
        // high mass -> backpack capacity.
        if (Coins > 0)
        {
            pawn.GiveInventory('ArmorBonus', Coins * 2);
        }

        if (Goombas > 0)
        {
            pawn.GiveInventory('HealthBonus', Goombas * 3);
        }

        if (Bobombs > 0)
        {
            pawn.GiveInventory('RocketAmmo', Bobombs * 2);
        }

        if (Bobombs >= 2)
        {
            pawn.GiveInventory('RocketLauncher', 1);
        }

        if (Mass >= 4.0)
        {
            pawn.GiveInventory('Backpack', 1);
        }

        pawn.A_PrintBold(
            String.Format(
                "NEXO HANDOFF\nSM64 -> DOOM\nMasa %.2f | Monedas %d | Goombas %d | Bob-ombs %d\nScore %d\n\nM2: ESTABILIZA LA BRECHA\nElimina %d hostiles",
                Mass, Coins, Goombas, Bobombs, InheritedScore, M2Goal
            ),
            9.0
        );

        Console.Printf(
            "[NEXO] Handoff applied: mass=%.2f coins=%d goombas=%d bobombs=%d score=%d\n",
            Mass, Coins, Goombas, Bobombs, InheritedScore
        );
        Console.Printf(
            "[NEXO] Perspective adapter: third_person(SM64) -> first_person(DOOM), body_ready=%d\n",
            CVarBool('nexo_avatar_body_ready')
        );
        Console.Printf(
            "[NEXO] Mario identity audio: %s\n",
            CVarBool('nexo_mario_sfx') ? "enabled" : "disabled/local-assets-missing"
        );
        Console.Printf(
            "[NEXO] M2 started: STABILIZE_BREACH goal=%d\n",
            M2Goal
        );

        Applied = true;
    }

    override void WorldTick()
    {
        if (PerspectiveTicks > 0)
        {
            PerspectiveTicks--;
            if (PerspectiveTicks <= 0)
            {
                EndPerspectiveTransition();
            }
        }

        if (!IdentityActive) return;

        let pawn = players[consoleplayer].mo;
        if (pawn == null) return;

        int buttons = players[consoleplayer].cmd.buttons;

        if ((buttons & BT_JUMP) && !(LastButtons & BT_JUMP))
        {
            PlayMarioJump(pawn);
        }

        if ((buttons & BT_USE) && !(LastButtons & BT_USE))
        {
            PlayMarioUse(pawn);
        }

        if (HurtCooldown > 0)
        {
            HurtCooldown--;
        }

        if (LastHealth > 0 && pawn.health > 0 && pawn.health < LastHealth && HurtCooldown <= 0)
        {
            PlayMarioHurt(pawn);
            HurtCooldown = 18;
        }

        LastButtons = buttons;
        LastHealth = pawn.health;
    }

    override void PlayerDied(PlayerEvent e)
    {
        if (!IdentityActive) return;

        let pawn = players[e.PlayerNumber].mo;
        PlayMarioDeath(pawn);
    }

    override void WorldThingDied(WorldEvent e)
    {
        if (!InM2Map) return;
        if (!Applied || M2Complete) return;
        if (e.Thing == null) return;
        if (!e.Thing.bIsMonster) return;

        M2Kills++;
        M2Score = InheritedScore + M2Kills * 500;

        PrintMission(
            String.Format(
                "NEXO M2 — ESTABILIZA LA BRECHA\nHOSTILES %d / %d\nSCORE CADENA %d",
                M2Kills, M2Goal, M2Score
            ),
            2.5
        );

        Console.Printf(
            "[NEXO] M2 progress: kills=%d/%d score=%d\n",
            M2Kills, M2Goal, M2Score
        );

        if (M2Kills >= M2Goal)
        {
            M2Complete = true;
            M2Score = InheritedScore + M2Kills * 500 + 3000;

            PrintMission(
                String.Format(
                    "BRECHA ESTABILIZADA\nHOSTILES %d / %d\nBUSCA LA SALIDA DE MAP01\nNEXO GATE ARMADO\nSCORE %d",
                    M2Kills, M2Goal, M2Score
                ),
                8.0
            );

            PlayMarioCelebrate(players[consoleplayer].mo);

            Console.Printf(
                "[NEXO] M2 COMPLETE: kills=%d score=%d. Reach MAP01 exit.\n",
                M2Kills, M2Score
            );
        }
    }

    override void WorldUnloaded(WorldEvent e)
    {
        EndPerspectiveTransition();

        if (!InM2Map) return;
        if (!Applied || !M2Complete) return;

        // Structured handoff line consumed by bridge/doom_handoff.py.
        // Target NEXO_HUB lets the orchestrator decide the third world.
        Console.Printf(
            "[NEXO_HANDOFF] source=DOOM_MAP01 target=NEXO_HUB mission=M2_STABILIZE_BREACH kills=%d score=%d mass=%.2f coins=%d goombas=%d bobombs=%d perspective=first_person nextmap=%s\n",
            M2Kills,
            M2Score,
            Mass,
            Coins,
            Goombas,
            Bobombs,
            e.NextMap
        );
    }
}
