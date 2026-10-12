# NEXO Mashup Lab

## Vertical slice actual: M1 — CARGA IMPOSIBLE

El prototipo ya no busca sólo "hacer un Katamari".

El loop actual es:

```
RECOLECTAR
  -> CRECER
  -> COMPLETAR CARGA
  -> VOLVER AL PUNTO INICIAL
  -> NEXO GATE
  -> HANDOFF AL SIGUIENTE MUNDO
```

## Requisitos M1

En **Bob-omb Battlefield**:

- 5 monedas
- 4 Goombas
- 2 Bob-ombs
- masa >= 3.80

Al cumplirlos aparece un **NEXO GATE** en el punto donde comenzaste el nivel.

Vuelve y atraviesa el gate para terminar la misión.

El destino guardado del primer handoff es **DOOM**. Todavía no lanza DOOM: esta fase valida el contrato de transición y el loop completo.

## Cambios de física/presentación

### Rigid attachments

Los objetos pegados ya no se corrigen individualmente contra el piso.

Mantienen una posición rígida sobre la bola. Si quedan detrás de suelo/pared, se ocultan temporalmente y reaparecen al emerger.

### Compact Mode

La masa lógica puede ser grande, pero el tamaño visual se adapta al espacio mediante raycasts.

En pasillos o bajo techos verás:

`COMPACT`

La masa/progresión NO se pierde.

Mario conserva siempre su física nativa.

## Actualizar

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Reinicia SM64CoopDX.

## Prueba recomendada

1. En el castillo, confirma que el mod no pone la bola.
2. Entra a Bob-omb Battlefield.
3. Recolecta la carga marcada en HUD.
4. Observa attachments cerca del suelo/pared.
5. Lleva la bola grande por espacios estrechos y observa COMPACT.
6. Completa requisitos.
7. Regresa al NEXO GATE del inicio.
8. Tócalo y revisa score/best/time + `HANDOFF PREPARADO -> DOOM`.

El modelo del gate y la esfera siguen siendo placeholders funcionales.
