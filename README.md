# NEXO Mashup Lab

## Estado

La navegación estable de A6.6 se conserva.

La prueba actual combina dos cosas:

**A6.8**
- la bola sube visualmente al crecer;
- deja de hundirse en el piso;
- attachments quedan fuera de la superficie en vez de embebidos.

**A7-A8 — slice 1**
- monedas;
- Goombas;
- Bob-ombs con umbral de tamaño;
- HUD de progresión;
- feedback "demasiado grande".

## Progresión inicial

| Objeto | Tamaño mínimo | Crecimiento |
|---|---:|---:|
| Moneda | 1.80 | +0.08 |
| Goomba | 1.80 | +0.35 |
| Bob-omb | 2.70 | +0.50 |

Bob-omb no debe desaparecer si todavía eres pequeño.

## Actualizar

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Reinicia SM64CoopDX.

## Qué probar

1. Navegación: puertas y entrada al escenario deben seguir funcionando.
2. Absorbe varios Goombas y observa si la esfera crece hacia arriba, sin hundirse.
3. Detente y mira si los Goombas quedan sobre la superficie, no dentro.
4. Recoge monedas con la bola.
5. Acércate a un Bob-omb antes de TAM 2.70: debe aparecer "DEMASIADO GRANDE".
6. Crece hasta 2.70 o más.
7. Absorbe un Bob-omb y confirma que queda pegado.
8. Comprueba que el giro sigue lento y natural.

No usamos todavía Koopas: primero validamos que el sistema genérico de categorías/umbrales sea estable.
