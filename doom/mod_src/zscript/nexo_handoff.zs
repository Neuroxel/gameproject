class NexoHandoffHandler : EventHandler
{
    bool Applied;
    bool InM2Map;

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

    override void WorldLoaded(WorldEvent e)
    {
        InM2Map = Level.MapName.CompareNoCase("MAP01") == 0;

        // M2 belongs only to the arrival map. Once the player crosses the
        // semantic gate into MAP02, the original SM64 handoff must not be
        // applied again.
        if (!InM2Map)
        {
            Applied = false;
        }
    }

    override void PlayerEntered(PlayerEvent e)
    {
        if (!InM2Map) return;
        if (Applied) return;
        if (!CVarBool('nexo_handoff')) return;

        let pawn = players[e.PlayerNumber].mo;
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
            "[NEXO] M2 started: STABILIZE_BREACH goal=%d\n",
            M2Goal
        );

        Applied = true;
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

            Console.Printf(
                "[NEXO] M2 COMPLETE: kills=%d score=%d. Reach MAP01 exit.\n",
                M2Kills, M2Score
            );
        }
    }

    override void WorldUnloaded(WorldEvent e)
    {
        if (!InM2Map) return;
        if (!Applied || !M2Complete) return;

        // Structured handoff line consumed by bridge/doom_handoff.py.
        // Target NEXO_HUB lets the orchestrator decide the third world.
        Console.Printf(
            "[NEXO_HANDOFF] source=DOOM_MAP01 target=NEXO_HUB mission=M2_STABILIZE_BREACH kills=%d score=%d mass=%.2f coins=%d goombas=%d bobombs=%d nextmap=%s\n",
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
