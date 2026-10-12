# NEXO Mashup Lab

## Estado actual

- A0 — PASS
- A1-A3.1 — PASS
- A4-A5 — PASS
- A6 — PASS: crecimiento visible
- **A6.5 — VALIDACIÓN ACTIVA: control directo + Goombas pegados**

## Cambio importante

La bola ya no se controla empujándola físicamente con Mario.

Ahora:

```
stick analogico
      ↓
control directo de la bola
      ↓
Mario se mantiene detrás visualmente
```

Esto está inspirado en la lógica de Katamari, pero simplificado a un stick relativo a cámara para hacerlo más accesible.

### B

B activa un **DASH**.

### Absorción

Los Goombas ya no deberían simplemente desaparecer. El enemigo activo se reemplaza por un **cascarón visual pasivo** que queda pegado a la superficie y gira/se desplaza con la bola.

## Prueba recomendada

1. Actualiza e instala:
```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```
2. Reinicia SM64CoopDX.
3. En Bob-omb Battlefield:
   - mueve el stick sin intentar empujar manualmente la bola;
   - cambia de dirección varias veces;
   - prueba detenerte;
   - pulsa B para dash;
   - absorbe 2-4 Goombas;
   - comprueba que quedan visibles pegados.

Lo más importante de esta versión no es la física perfecta: es comprobar si **por fin se siente controlable y divertido**.

> El modelo con puntas sigue siendo provisional.
