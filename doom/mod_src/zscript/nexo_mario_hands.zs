class NexoMarioHandStates : Weapon
{
    // These are static first-person hand layers. The actual PNG sprite lumps
    // are injected into the local runtime PK3 only when
    // assets_local/mario_hands/READY exists.
    //
    // Layer ordering is handled by NexoMarioDoomPlayer:
    //   -2 = behind PSP_WEAPON(1)
    //    2 = in front of PSP_WEAPON(1)
    States
    {
    FistBack:
        NHFB A -1;
        Stop;
    FistFront:
        NHFF A -1;
        Stop;

    ChainsawBack:
        NHCB A -1;
        Stop;
    ChainsawFront:
        NHCF A -1;
        Stop;

    PistolBack:
        NHPB A -1;
        Stop;
    PistolFront:
        NHPF A -1;
        Stop;

    ShotgunBack:
        NHSB A -1;
        Stop;
    ShotgunFront:
        NHSF A -1;
        Stop;

    SuperShotgunBack:
        NH2B A -1;
        Stop;
    SuperShotgunFront:
        NH2F A -1;
        Stop;

    ChaingunBack:
        NHGB A -1;
        Stop;
    ChaingunFront:
        NHGF A -1;
        Stop;

    RocketBack:
        NHRB A -1;
        Stop;
    RocketFront:
        NHRF A -1;
        Stop;

    PlasmaBack:
        NHEB A -1;
        Stop;
    PlasmaFront:
        NHEF A -1;
        Stop;

    BFGBack:
        NHBB A -1;
        Stop;
    BFGFront:
        NHBF A -1;
        Stop;
    }
}
