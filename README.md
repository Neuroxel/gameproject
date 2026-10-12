# NEXO Mashup Lab

## Estado

- A0-A6 — PASS
- A6.5 — FAIL
- A6.6 — PASS: navegación estable con Mario como autoridad física
- **A6.7 — VALIDACIÓN ACTIVA: objetos realmente pegados + giro natural**

## Qué cambió

No se modifica la arquitectura de navegación que ya funcionó.

Sólo se corrige la presentación:

- radio visual realista del modelo provisional;
- Goombas mucho más cerca de la superficie;
- leve incrustación visual para que parezcan pegados;
- giro basado en distancia/radio en vez de un multiplicador fijo;
- velocidad visual de giro reducida;
- yaw visual suavizado para evitar que los objetos orbiten al doblar.

## Actualizar

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Reinicia SM64CoopDX.

## Qué probar

1. Confirma primero que puedes seguir entrando al escenario y atravesando puertas.
2. Absorbe 2-4 Goombas.
3. Detente y mira si ahora quedan realmente tocando la esfera.
4. Avanza recto: el giro debe ser mucho más lento.
5. Haz curvas: los Goombas no deberían hacer órbitas bruscas.
6. Comprueba que el crecimiento continúa.

La esfera con puntas sigue siendo provisional; A6.7 sólo busca estabilizar la ilusión Katamari antes de añadir más categorías.
