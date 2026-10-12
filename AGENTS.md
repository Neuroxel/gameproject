# AGENTS.md

## Rol del agente local

Eres el ejecutor local del proyecto NEXO Mashup Lab. El estado canónico está en `NEXO_STATE.md`.

## Prioridades

1. No expandir alcance sin necesidad.
2. Resolver sólo el gate actual.
3. Preservar código y resultados existentes.
4. No instalar tooling adicional salvo que el gate actual lo requiera.
5. No copiar, mover, modificar ni subir ROMs o assets propietarios.
6. Antes de cambios amplios, leer `README.md` y `NEXO_STATE.md`.

## Fase actual

A0 = PASS.

Gate activo: **A1-A3.1**.

Objetivos:

- confirmar que el modelo provisional se percibe realmente 3D;
- confirmar gravedad/rodado/colisión básica;
- confirmar empuje corporal;
- confirmar que B cerca del objeto produce un impulso claramente superior;
- confirmar que D-Pad abajo lo reposiciona.

## Directorio de mods esperado en macOS

`~/Library/Application Support/sm64coopdx/mods/`

## Política de depuración

Si A1-A3.1 falla:

1. comprobar que el repo local está actualizado;
2. ejecutar `bash scripts/install-macos.sh`;
3. iniciar SM64CoopDX con consola/logs si el problema no es visual;
4. capturar el error o comportamiento exacto;
5. hacer la corrección mínima;
6. documentar resultado en `NEXO_STATE.md`.

No comenzar A4 hasta A1-A3.1 PASS.
