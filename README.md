# NEXO Mashup Lab

## Estado

- A0-A6 — PASS
- A6.5 — **FAIL**
- **A6.6 — VALIDACIÓN ACTIVA**

## Cambio crítico

La versión anterior hacía que la bola fuera la autoridad física y pegaba a Mario detrás. Eso rompió puertas, superficies y navegación.

Ahora es al revés:

```
Mario nativo
  ↓
física / puertas / escaleras / pendientes
  ↓
bola visual delante de Mario
  ↓
absorción + crecimiento + objetos pegados
```

La bola **no tiene colisión propia con el mundo**. Es visual y sirve como volumen de absorción.

Esto debería permitir entrar al castillo y pasar puertas con el movimiento original de SM64.

## Prueba

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Reinicia SM64CoopDX.

Prueba primero navegación, antes de ir a los Goombas:

1. caminar/correr normalmente;
2. entrar al castillo;
3. atravesar una puerta;
4. entrar a Bob-omb Battlefield;
5. subir y bajar pendientes/escalones;
6. confirmar que la bola no te bloquea.

Después prueba absorción:

7. absorber 2-4 Goombas;
8. comprobar crecimiento;
9. comprobar que quedan visibles pegados.

Si todo eso pasa, podremos avanzar a categorías de objetos sin seguir reparando la locomoción.

> La esfera con puntas sigue siendo un modelo provisional.
