# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Gates confirmados

- A0 — PASS.
- A1-A3.1 — PASS.
- A4-A5 — PASS.
- A6 — PASS: crecimiento visual confirmado.

## A6.5 — FAIL

Nueva evidencia del usuario:

- Mario se mantenía pegado a la bola;
- el sistema se bugueaba en superficies/espacios estrechos;
- costó entrar al castillo;
- no se pudo atravesar correctamente la puerta hacia la primera etapa;
- el volumen/espacio de la bola interfería con navegación.

Conclusión: el modelo **bola = autoridad física + Mario follower** es incorrecto para SM64CoopDX. No se seguirá ajustando con más parches de radios o step-assist.

## A6.6 — ACTIVE

### Cambio arquitectónico

Se invierte la autoridad:

**Mario = física/navegación real**

**Bola = representación visual + detector de absorción**

El mod ya NO modifica:

- `m.pos`;
- `m.vel`;
- `m.forwardVel`;
- acciones de Mario;
- colisión de Mario.

Mario conserva íntegramente su controlador nativo para:

- puertas;
- escaleras;
- pendientes;
- pasillos;
- transiciones;
- habitaciones;
- saltos y movimiento.

### Bola

La bola:

- sigue visualmente delante de Mario;
- se posiciona después del update nativo de Mario;
- se ajusta visualmente al suelo bajo ella;
- no tiene hitbox, hurtbox, wall hitbox ni interacción;
- es intangible;
- no ejecuta física propia;
- gira visualmente según distancia recorrida;
- mantiene crecimiento;
- mantiene radio de absorción creciente.

Por diseño, el tamaño visual ya no agranda la colisión del mundo. Esto sacrifica fidelidad física para preservar jugabilidad y navegación. Más adelante, si se necesita, podremos introducir colisiones contextuales sólo en arenas abiertas.

### Attachments

Se preserva la arquitectura:

enemigo activo -> cascarón visual pasivo pegado -> enemigo activo eliminado.

Los Goombas adheridos no tienen IA, daño ni colisión.

### Criterios de PASS A6.6

1. Mario vuelve a moverse exactamente como SM64 normal.
2. Puede entrar al castillo.
3. Puede atravesar puertas y entrar a Bob-omb Battlefield.
4. Puede subir/bajar superficies y escalones normales sin quedar pegado a la bola.
5. La bola permanece visualmente delante de Mario.
6. La bola no bloquea puertas/paredes.
7. Goombas siguen absorbiéndose.
8. Goombas absorbidos quedan visibles pegados.
9. La bola sigue creciendo visualmente.
10. No aparecen nuevos crashes o soft-locks.

## Decisión de diseño

Para este prototipo, **jugabilidad > colisión física literal del katamari**.

No se intentará que una esfera visual de gran tamaño actúe como collider rígido dentro de niveles diseñados para el hitbox pequeño de Mario. Ese enfoque rompe puertas y geometría del juego anfitrión.

Si A6.6 pasa, A7-A8 añadirá categorías y umbrales de absorción sin tocar la navegación de Mario.

## Próximo gate

A7-A8:

- monedas/objetos pequeños;
- Goombas;
- Bob-ombs;
- Koopas;
- objetos mayores;
- umbrales de tamaño;
- feedback de "demasiado grande";
- attachments visuales por categoría.

## Reglas

- No versionar ROMs.
- No instalar tooling pesado.
- Priorizar evidencia nueva.
- No restaurar A6.5.
