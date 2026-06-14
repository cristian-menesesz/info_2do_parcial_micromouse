# Simulador Micromouse — Modified Flood Fill Algorithm

## Algoritmo de navegación

El agente implementado en `cerebro_estudiante.gd` ejecuta el **Modified Flood Fill Algorithm** (MFF) [1][3], variante en línea del flood fill clásico [2] adaptada a la exploración incremental de laberintos bajo información parcial.

---

## Fundamento

El MFF asigna a cada celda del laberinto un valor entero que representa la distancia mínima estimada a la meta, propagada mediante BFS inverso desde la meta hacia el resto de la grilla. El agente se desplaza en cada paso hacia la celda vecina con menor valor. La distinción crítica respecto al flood fill offline es que la propagación opera sobre el **mapa creído por el agente** (`_mapa: Laberinto`), no sobre el laberinto real. Las celdas no sensadas se tratan como libres de paredes — suposición optimista que garantiza exploración completa sin requerir conocimiento previo de la estructura [1].

---

## Implementación

### Estado del agente

`CerebroEstudiante` mantiene tres estructuras de datos centrales:

- `_mapa: Laberinto` — instancia de `Laberinto.vacio(ancho, alto)` inicializada en `preparar()`. Contiene únicamente los bordes exteriores; las paredes internas se incorporan exclusivamente por sensado.
- `_distancias: Array` — grilla `[alto][ancho]` de enteros inicializada a `999999`. Recalculada en cada tick mediante `_flood_fill()`.
- `_visitadas: Dictionary` — conjunto de celdas cuya vecindad ha sido sensada completamente.

El agente opera bajo una máquina de tres fases (`enum Fase { EXPLORANDO, VOLVIENDO, SPEED_RUN }`), despachada en `paso(raton)` a través de un `match _fase`.

---

### Fase EXPLORANDO

Invocada por `game.gd` cada tick mientras `_fase == Fase.EXPLORANDO`. La secuencia en `_paso_explorando()` es:

**1. Sensado local** — `_anotar_paredes()` consulta `raton.pared_frente()`, `raton.pared_izquierda()` y `raton.pared_derecha()`, convierte cada lectura positiva al rumbo absoluto correspondiente mediante aritmética modular (`(raton.rumbo + k) % 4`) y llama a `_mapa.poner_pared()`. Esta función propaga la pared en ambas direcciones (celda y vecina), manteniendo la consistencia del grafo.

**2. Recálculo de distancias** — `_flood_fill(metas, false)` reinicializa `_distancias` a `999999` y ejecuta BFS desde las celdas en `metas` (distancia 0). Para cada celda en la cola, propaga a vecinas accesibles según `_mapa.tiene_pared()`. El parámetro `solo_conocidas=false` permite propagar a través de celdas no visitadas, asumiendo paso libre — esto es la suposición optimista. El recálculo completo en cada tick es viable dado el tamaño de grilla (máx. 16×16 = 256 celdas).

**3. Movimiento greedy** — `_mover_hacia_menor_distancia()` llama a `_mejor_rumbo()`, que itera las cuatro direcciones en `Laberinto.DELTAS` y devuelve aquella cuya vecina tiene `_distancias[y][x]` mínimo sin pared interpuesta. El movimiento es estrictamente atómico: si el rumbo actual coincide con el objetivo, se llama a `raton.avanzar()`; si no, `_girar_hacia()` ejecuta una sola rotación (`girar_derecha()` o `girar_izquierda()` según `(rumbo_objetivo - raton.rumbo + 4) % 4`) y el avance ocurre en el tick siguiente.

---

### Fase VOLVIENDO

Activada desde `game.gd` mediante `cerebro.iniciar_vuelta()` al detectar `laberinto.es_meta(raton.celda)`. `iniciar_vuelta()` invoca `_flood_fill([inicio], true)` — mismo BFS pero con destino `inicio` y `solo_conocidas=true`, lo que restringe la propagación al subgrafo de celdas ya sensadas. Esto impide que el agente transite por zonas no exploradas cuyas paredes son desconocidas. `_paso_volviendo()` aplica `_mover_hacia_menor_distancia()` sin llamar a `_anotar_paredes()` — el agente no sensa durante la vuelta, navega exclusivamente sobre el mapa ya construido. Al alcanzar `raton.celda == inicio`, activa `_calcular_ruta_speed_run()` y transiciona a `Fase.SPEED_RUN`.

---

### Fase SPEED_RUN

`_calcular_ruta_speed_run()` ejecuta `_flood_fill(metas, true)` — BFS desde metas restringido a celdas conocidas — y reconstruye `_ruta_speed_run: Array[Vector2i]` siguiendo iterativamente `_mejor_rumbo()` desde `inicio` hasta `_mapa.es_meta()`. Esta ruta representa el camino más corto conocido, potencialmente más corto que la trayectoria de exploración almacenada en `_ruta_exploracion`.

`_paso_speed_run()` consume `_ruta_speed_run` mediante `_idx_speed`, avanzando celda a celda sin llamar a `_anotar_paredes()` — el agente navega sin sensar, confiando en el mapa construido durante la exploración. La dirección entre celdas consecutivas se obtiene por `_direccion_entre()`, que compara el delta de posición contra `Laberinto.DELTAS`.

---

### Usos del flood fill

| Llamada | `hasta` | `solo_conocidas` | Propósito |
|---------|---------|-----------------|-----------|
| `_flood_fill(metas, false)` | metas | no | Exploración optimista |
| `_flood_fill([inicio], true)` | inicio | sí | Vuelta por zona sensada |
| `_flood_fill(metas, true)` | metas | sí | Ruta óptima del speed run |

---

### Interfaz con el simulador

`game.gd` invoca `cerebro.paso(raton)` una vez por tick del `paso_timer`. El ratón (`raton.gd`) garantiza exactamente una acción física por llamada mediante el flag `ocupado()`, que bloquea el timer mientras el tween de animación está activo. La fase del cerebro (`cerebro._fase`) es observada directamente por `game.gd` en `_ejecutar_un_paso()` para detectar la transición `VOLVIENDO → SPEED_RUN` y capturar `_pasos_al_iniciar_speed_run = raton.pasos`, de modo que `_pasos_speed_run = raton.pasos - _pasos_al_iniciar_speed_run` contabiliza exclusivamente los pasos de esa fase.

El mapa descubierto se expone mediante `get_mapa()` y `get_visitadas()` para alimentar `vista_mapa_raton` y `overlay_visitadas`, respectivamente. Las rutas se exponen mediante `ruta_exploracion()` y `ruta_speed_run()` para `overlay_rutas`.

---

## Referencias

[1] G. Law, "Quantitative Comparison of Flood Fill and Modified Flood Fill Algorithms," *IJCTE*, pp. 503–508, 2013, doi: [10.7763/IJCTE.2013.V5.738](https://doi.org/10.7763/IJCTE.2013.V5.738).

[2] "Flood fill," *Wikipedia*. Dec. 31, 2025. Accessed: Jun. 13, 2026. [Online]. Available: https://en.wikipedia.org/w/index.php?title=Flood_fill&oldid=1330386064

[3] "The Flood & Modified Flood Fill Algorithm – MICROMOUSE," *IEEE Student Branch*. Accessed: Jun. 13, 2026. [Online]. Available: https://ieeecharusat.wordpress.com/2010/09/23/the-flood-modified-flood-fill-algorithm-micromouse/
