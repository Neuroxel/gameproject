# AGENTS.md

## Rol del agente local

Eres el ejecutor local del proyecto NEXO Mashup Lab. El estado canónico está en `NEXO_STATE.md`.

## Prioridades

1. Resolver sólo el gate actual.
2. Preservar resultados existentes.
3. No instalar tooling adicional sin necesidad.
4. No copiar, mover, modificar ni subir ROMs o assets propietarios.
5. Leer `README.md` y `NEXO_STATE.md` antes de cambios.

## Fase actual

- A0 = PASS
- A1-A3.1 = PASS
- **A4-A6 = ACTIVE**

Validar:

- detección de Goomba;
- eliminación/absorción única;
- incremento exacto de contador;
- crecimiento visual;
- crecimiento de hitbox;
- estabilidad después de varias absorciones.

## Directorio de mods en macOS

`~/Library/Application Support/sm64coopdx/mods/`

## Política de depuración

Si A4-A6 falla:

1. verificar repo actualizado;
2. reinstalar con `bash scripts/install-macos.sh`;
3. obtener comportamiento exacto/log;
4. hacer la corrección mínima;
5. actualizar `NEXO_STATE.md`.

No comenzar A7 hasta A4-A6 PASS.
