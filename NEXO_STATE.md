# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Objetivo

Construir un mashup jugable y observable partiendo de SM64CoopDX. La prioridad es diversión y legibilidad del sistema, no fidelidad a una simulación física innecesariamente difícil.

## Gates cerrados

- A0 — PASS: pipeline del mod.
- A1-A3.1 — PASS: objeto 3D, física y respuesta diferenciada.
- A4 — PASS: detección de Goombas.
- A5 — PASS: absorción/eliminación.
- A6 — PASS: crecimiento visual real confirmado por el usuario. La bola llegó a escala ~4.00 tras cuatro Goombas.

## Cambio de arquitectura de control

La implementación anterior trataba la bola como un prop físico independiente que Mario debía perseguir y empujar. La validación mostró que seguía siendo difícil de manejar.

Se abandona ese modelo.

La referencia Katamari controla el katamari directamente; el personaje visualmente lo empuja. Por eso A6.5 cambia a **direct-drive**:

- stick analógico -> dirección/velocidad objetivo de la bola;
- Mario se posiciona automáticamente detrás de ella;
- la cámara sigue a Mario y, por extensión, a la bola;
- B activa un dash;
- la bola mantiene física con terreno/paredes, pero deja de depender de colisiones de Mario para moverse;
- pequeño step-assist para peldaños/relieves bajos.

## A6.5 — PENDING VALIDATION

### Control

1. `m.intendedYaw` entrega dirección relativa a cámara.
2. `m.intendedMag` entrega magnitud analógica.
3. La bola gira suavemente hacia esa dirección con `approach_s16_symmetric`.
4. Acelera/frena hacia una velocidad objetivo.
5. Mario es reposicionado detrás de la bola cada frame.
6. La bola es intangible respecto de Mario para evitar que la física de empuje compita con el control directo.
7. B = dash.
8. El crecimiento introduce sólo una penalización de masa suave.

### Objetos pegados

Al absorber un Goomba:

1. se captura su posición relativa;
2. se crea un Goomba visual con comportamiento propio, sin IA ni daño;
3. se elimina el enemigo activo;
4. el cascarón visual queda sobre la superficie de la bola;
5. su vector radial se actualiza con la rotación incremental de la bola;
6. el objeto viaja y gira con la bola;
7. no participa en colisiones ni lógica enemiga.

Esto preserva el feedback visual tipo Katamari sin arrastrar IA/hitboxes de los enemigos absorbidos.

### Criterios de PASS

- mover el stick debe dirigir la bola de forma inmediata y predecible;
- no debería ser necesario perseguirla o ponerse exactamente detrás para empujarla;
- Mario debe mantenerse visualmente detrás de la bola la mayor parte del tiempo;
- B debe producir un dash reconocible;
- al absorber un Goomba, debe seguir visible pegado a la bola;
- el Goomba pegado debe desplazarse con la bola sin atacar ni interferir;
- varios Goombas pegados no deben provocar crash;
- crecimiento continúa funcionando;
- pequeños peldaños deben sentirse menos frustrantes.

## Próximo gate

Si A6.5 = PASS:

A7-A8 — clases de objetos y progresión:
- objetos diminutos;
- Goombas;
- Bob-ombs;
- Koopas;
- objetos mayores;
- umbrales por tamaño;
- feedback de objetos todavía demasiado grandes.

No comenzar GTA/Tony Hawk/Crazy Taxi hasta validar el loop Katamari.

## Limitaciones actuales

- Spiny Ball sigue siendo modelo provisional.
- Attachments aún son sólo Goombas.
- Orientación de los cascarones es aproximada, no una simulación rígida exacta.
- Multiplayer no validado.
- No se busca reproducir exactamente el esquema twin-stick original: priorizamos control fácil con un stick relativo a cámara.

## Reglas

- Nunca versionar ROMs ni dumps.
- No instalar tooling pesado sin necesidad.
- Priorizar evidencia nueva sobre decisiones previas.
