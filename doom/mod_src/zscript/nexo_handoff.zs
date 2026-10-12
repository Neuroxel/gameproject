class NexoHandoffHandler : EventHandler
{
    bool Applied;
    bool InM2Map;
    bool IdentityActive;

    // Perspective adapter state.
    int PerspectiveTicks;
    int PerspectivePlayer;
    bool PerspectiveBodyVisible;

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

    void RefreshArrivalState()
    {
        // Pinned g4.14.2 calls PlayerEntered BEFORE WorldLoaded on a fresh
        // level load. Arrival-critical state must therefore be derived here
        // as well as in WorldLoaded; relying on WorldLoaded alone leaves the
        // first PlayerEntered event with default false fields.
        InM2Map = Level.MapName ~== "MAP01";
        IdentityActive = CVarBool('nexo_handoff');
    }

    void LogMarioSfxResource(String label, String path)
    {
        int lump = Wads.CheckNumForFullName(path);
        int bytes = lump >= 0 ? Wads.GetLumpLength(lump) : -1;

        Console.Printf(
            "[NEXO] Mario SFX resource: %s path=%s lump=%d bytes=%d\n",
            label,
            path,
            lump,
            bytes
        );
    }

    void LogMarioSfxProbe()
    {
        if (!CVarBool('nexo_mario_sfx'))
        {
            Console.Printf("[NEXO] Mario SFX probe: disabled by CVAR\n");
            return;
        }

        // This distinguishes PK3/filesystem resolution from decoder failure
        // using APIs exposed by the exact pinned g4.14.2 ZScript runtime.
        LogMarioSfxResource("jump", "sounds/nexo/mario/jump.dmx");
        LogMarioSfxResource("hurt", "sounds/nexo/mario/hurt.dmx");
        LogMarioSfxResource("death", "sounds/nexo/mario/death.dmx");
        LogMarioSfxResource("use", "sounds/nexo/mario/use.dmx");
        LogMarioSfxResource("portal", "sounds/nexo/mario/portal.dmx");
        LogMarioSfxResource("celebrate", "sounds/nexo/mario/celebrate.dmx");

        Console.Printf(
            "[NEXO] Mario SFX probe seconds: jump=%.3f hurt=%.3f death=%.3f use=%.3f portal=%.3f celebrate=%.3f\n",
            S_GetLength("nexo/mario/jump"),
            S_GetLength("nexo/mario/hurt"),
            S_GetLength("nexo/mario/death"),
            S_GetLength("nexo/mario/use"),
            S_GetLength("nexo/mario/portal"),
            S_GetLength("nexo/mario/celebrate")
        );
    }

    void PrintMission(String text, double duration = 4.0)
    {
        let pawn = players[consoleplayer].mo;
        if (pawn != null)
        {
            pawn.A_PrintBold(text, duration);
        }
    }

    void PlayMarioPortal(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        S_StartSound("nexo/mario/portal", CHAN_5, CHANF_UI, 1.0, ATTN_NONE);
    }

    void PlayMarioCelebrate(Actor pawn)
    {
        if (!CVarBool('nexo_mario_sfx') || pawn == null) return;
        S_StartSound("nexo/mario/celebrate", CHAN_5, CHANF_UI, 1.0, ATTN_NONE);
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
        RefreshArrivalState();

        Console.Printf(
            "[NEXO] WorldLoaded: map=%s handoff=%d mario_sfx=%d applied=%d\n",
            Level.MapName,
            IdentityActive,
            CVarBool('nexo_mario_sfx'),
            Applied
        );
    }

    override void PlayerEntered(PlayerEvent e)
    {
        RefreshArrivalState();

        PerspectivePlayer = -1;
        PerspectiveTicks = 0;
        PerspectiveBodyVisible = false;

        let pawn = players[e.PlayerNumber].mo;

        Console.Printf(
            "[NEXO] PlayerEntered: map=%s handoff=%d mario_sfx=%d m2=%d\n",
            Level.MapName,
            IdentityActive,
            CVarBool('nexo_mario_sfx'),
            InM2Map
        );

        // Mario's identity is world-independent inside the DOOM adapter.
        // M2 itself is still restricted to MAP01.
        if (IdentityActive && pawn != null)
        {
            // Cross-engine camera normalization: never inherit a stale/extreme
            // pitch into the first-person destination. The controller remains
            // fully live immediately after this one-time center operation.
            pawn.Pitch = 0.0;

            if (InM2Map)
            {
                LogMarioSfxProbe();
                if (CVarBool('nexo_mario_sfx'))
                {
                    Console.Printf("[NEXO] Mario portal cue requested: nexo/mario/portal on CHAN_5/UI\n");
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

        // Avatar audio is semantic, not raw-button-driven:
        // - jump belongs to confirmed Mario movement;
        // - pain/death belong to SNDINFO player semantics;
        // - USE belongs to the destination-world switch/door sound.
        //
        // Do not add an unconditional vocal grunt on BT_USE. The Mario "use"
        // resource remains in the local pack for explicit scripted moments,
        // diagnostics or future contextual interactions.
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
