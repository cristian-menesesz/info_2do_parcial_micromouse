extends Node2D

# Controlador principal: carga el laberinto, coloca al ratón y hace avanzar
# el cerebro un paso por tick del paso_timer. El núcleo (laberinto, sensado,
# movimiento, vista de dios) ya está resuelto; los huecos del parcial están
# marcados con "TODO (PARCIAL · ...)".

# Laberintos incluidos: 01_entrenamiento (8x8, perfecto: el wall-follower lo
# resuelve), 02_clasico y 03_clasico (16x16 con ciclos y meta central, estilo
# competencia: el wall-follower NO basta).
@export_file("*.maz") var archivo_laberinto: String = "res://mazes/01_entrenamiento.maz"
# Marca esta casilla (en el Inspector del nodo Game) para usar tu cerebro.
@export var usar_cerebro_estudiante: bool = false

const ORIGEN := Vector2(28, 44)
# La vista de dios dispone de ~608 px; la celda se adapta al tamaño del
# laberinto (38 px en los 16x16, más grande en los de entrenamiento).
var tam_celda := 38.0

var laberinto: Laberinto
var cerebro = null

@onready var vista_dios: VistaLaberinto = $vista_dios
@onready var vista_mapa_raton: VistaLaberinto = $vista_mapa_raton
@onready var raton: Raton = $raton
@onready var paso_timer: Timer = $paso_timer
@onready var hud = $ui/hud

@onready var sfx_paso: AudioStreamPlayer = $sfx_paso
@onready var sfx_choque: AudioStreamPlayer = $sfx_choque
@onready var sfx_meta: AudioStreamPlayer = $sfx_meta

signal pasos_cambiados(pasos: int)
signal visitadas_cambiadas(cantidad: int)
signal fase_cambiada(nombre: String)
signal corrida_terminada(exito: bool, pasos_exp: int, pasos_speed: int)

var _visitadas: Dictionary = {}
var _tiempo_inicio: float = 0.0
var _corrida_activa: bool = true

# === ESTADO DE LA CORRIDA (B3) ===
# Contrato sugerido para comunicarte con el HUD (hud.gd) sin acoplarlos:
#   signal pasos_cambiados(pasos: int)
#   signal visitadas_cambiadas(cantidad: int)
#   signal fase_cambiada(nombre: String)
#   signal corrida_terminada(exito: bool, pasos: int)
# TODO (PARCIAL · B1/B3): declara el estado de la corrida (fase, cronómetro,
# celdas visitadas) y sus señales.


func _ready() -> void:
	laberinto = Laberinto.desde_archivo(archivo_laberinto)
	tam_celda = minf(56.0, 608.0 / maxf(laberinto.ancho, laberinto.alto))
	vista_dios.configurar(laberinto, ORIGEN, tam_celda)
	raton.configurar(laberinto, ORIGEN, tam_celda)
	if usar_cerebro_estudiante:
		cerebro = CerebroEstudiante.new()
		cerebro.preparar(laberinto.ancho, laberinto.alto, laberinto.metas,
				laberinto.inicio)
	else:
		cerebro = CerebroWallFollower.new()

	raton.choque.connect(func(): sfx_choque.play())
	raton.paso_terminado.connect(func(): sfx_paso.play())

	pasos_cambiados.connect(hud.update_pasos)
	visitadas_cambiadas.connect(hud.update_visitadas)
	fase_cambiada.connect(hud.update_fase)

	_tiempo_inicio = Time.get_ticks_msec()
	_corrida_activa = true
	fase_cambiada.emit("EXPLORANDO")
	# La vista derecha ("mapa del ratón") queda vacía hasta que la conectes:
	# TODO (PARCIAL · M2): configura vista_mapa_raton con el laberinto que TU
	# cerebro descubre (Laberinto.vacio + poner_pared al sensar) y redibuja
	# cada vez que aprenda una pared. Distingue visitadas / no visitadas.


func _process(_delta: float) -> void:
	if _corrida_activa:
		var segundos = (Time.get_ticks_msec() - _tiempo_inicio) / 1000.0
		hud.update_tiempo(segundos)


func _on_paso_timer_timeout() -> void:
	if raton.ocupado():
		return
	cerebro.paso(raton)

	_visitadas[raton.celda] = true
	pasos_cambiados.emit(raton.pasos)
	visitadas_cambiadas.emit(_visitadas.size())

	if laberinto.es_meta(raton.celda):
		_meta_alcanzada()


func _meta_alcanzada() -> void:
	paso_timer.stop()
	sfx_meta.play()
	print("¡Meta alcanzada en ", raton.pasos, " pasos!")
	# TODO (PARCIAL · B3): esto debe ser una máquina de estados explícita
	# (EXPLORANDO → META → VOLVIENDO → SPEED_RUN → FIN), con pantalla final
	# (pasos de exploración vs. pasos del speed run) y opción de reiniciar.
	# TODO (PARCIAL · B4): sonido de meta (assets/sounds/meta.wav). Conecta
	# también raton.choque a un sonido de choque y cada avance a un tic.
	# TODO (PARCIAL · M3): aquí continúa el ciclo: volver al inicio y ejecutar
	# el speed run sobre el mapa descubierto, dibujando ambas rutas.
	# TODO (PARCIAL · M4): guarda el récord (mejores pasos) de ESTE laberinto
	# en user:// y muéstralo; añade un selector para cambiar de laberinto sin
	# tocar código.


# --- Botones del panel (ya conectados en el editor; cuerpos por hacer) ---

func _on_boton_pausa_pressed() -> void:
	# TODO (PARCIAL · B2): pausa/reanuda la corrida (paso_timer) y refleja el
	# estado en el texto del botón.
	pass


func _on_boton_paso_pressed() -> void:
	# TODO (PARCIAL · B2): con la corrida pausada, ejecuta UN solo paso del
	# cerebro (depuración paso a paso).
	pass


func _on_boton_velocidad_pressed() -> void:
	# TODO (PARCIAL · B2): cicla la velocidad (p. ej. x1 → x2 → x4 cambiando
	# paso_timer.wait_time y raton.duracion_paso).
	pass


func _on_boton_reiniciar_pressed() -> void:
	# TODO (PARCIAL · B2): reinicia la corrida completa: ratón al inicio,
	# cerebro nuevo, contadores a cero, timer corriendo.
	pass
