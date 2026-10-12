class NexoHandoffHandler : EventHandler
{
    bool Applied;

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

    override void PlayerEntered(PlayerEvent e)
    {
        if (Applied) return;
        if (!CVarBool('nexo_handoff')) return;

        let pawn = players[e.PlayerNumber].mo;
        if (pawn == null) return;

        int coins = CVarInt('nexo_coins');
        int goombas = CVarInt('nexo_goombas');
        int bobombs = CVarInt('nexo_bobombs');
        int score = CVarInt('nexo_score');
        double mass = CVarFloat('nexo_mass');

        // First cross-world semantic mapping:
        // coins -> armor, Goombas -> biomass/health, Bob-ombs -> explosives,
        // high mass -> backpack capacity.
        if (coins > 0)
        {
            pawn.GiveInventory('ArmorBonus', coins * 2);
        }

        if (goombas > 0)
        {
            pawn.GiveInventory('HealthBonus', goombas * 3);
        }

        if (bobombs > 0)
        {
            pawn.GiveInventory('RocketAmmo', bobombs * 2);
        }

        if (bobombs >= 2)
        {
            pawn.GiveInventory('RocketLauncher', 1);
        }

        if (mass >= 4.0)
        {
            pawn.GiveInventory('Backpack', 1);
        }

        pawn.A_PrintBold(
            String.Format(
                "NEXO HANDOFF\nSM64 -> DOOM\nMasa %.2f | Monedas %d | Goombas %d | Bob-ombs %d\nScore %d",
                mass, coins, goombas, bobombs, score
            ),
            8.0
        );

        Console.Printf(
            "[NEXO] Handoff applied: mass=%.2f coins=%d goombas=%d bobombs=%d score=%d\n",
            mass, coins, goombas, bobombs, score
        );

        Applied = true;
    }
}
