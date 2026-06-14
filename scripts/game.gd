extends Node2D

@export_file("*.maz") var archivo_laberinto: String = "res://mazes/03_clasico.maz"
@export var usar_cerebro_estudiante: bool = false

const ORIGEN := Vector2(28, 44)
var tam_celda := 38.0

var laberinto: Laberinto
var cerebro = null

@onready var vista_dios: VistaLaberinto = $vista_dios
@onready var vista_mapa_raton: VistaLaberinto = $vista_mapa_raton
@onready var raton: Raton = $raton
@onready var paso_timer: Timer = $paso_timer

@onready var hud = $ui/hud
@onready var btn_pausa: Button = $ui/hud/margen/columna/botones/boton_pausa
@onready var btn_velocidad: Button = $ui/hud/margen/columna/botones/boton_velocidad
@onready var pantalla_final: PanelContainer = $ui/pantalla_final
@onready var lbl_resultado_exp: Label = $ui/pantalla_final/col/exp_label
@onready var lbl_resultado_speed: Label = $ui/pantalla_final/col/speed_label

@onready var overlay_visitadas: Node2D = $overlay_visitadas
@onready var overlay_rutas: Node2D = $overlay_rutas

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

var _pausado: bool = false
const VELOCIDADES: Array[float] = [0.12, 0.06, 0.03]
const NOMBRES_VEL: Array[String] = ["Vel x1", "Vel x2", "Vel x4"]
var _idx_vel: int = 0

enum Fase { EXPLORANDO, META, VOLVIENDO, SPEED_RUN, FIN }
var _fase: Fase = Fase.EXPLORANDO
var _pasos_exploracion: int = 0
var _pasos_speed_run: int = 0
var _pasos_al_iniciar_speed_run: int = 0

const RECORDS_PATH = "user://records.cfg"
var _config: ConfigFile = ConfigFile.new()


func _iniciar_corrida() -> void:
	laberinto = Laberinto.desde_archivo(archivo_laberinto)
	tam_celda = minf(56.0, 608.0 / maxf(laberinto.ancho, laberinto.alto))
	vista_dios.configurar(laberinto, ORIGEN, tam_celda)
	raton.configurar(laberinto, ORIGEN, tam_celda)

	if usar_cerebro_estudiante:
		cerebro = CerebroEstudiante.new()
		cerebro.preparar(
			laberinto.ancho,
			laberinto.alto,
			laberinto.metas,
			laberinto.inicio
		)
		vista_mapa_raton.configurar(cerebro.get_mapa(), ORIGEN, tam_celda)
		overlay_visitadas.configurar(cerebro, ORIGEN, tam_celda)
		# --- STEP 7 (M3): conectar overlay de rutas ---
		overlay_rutas.configurar(cerebro, ORIGEN, tam_celda)
		overlay_visitadas.visible = true
		overlay_rutas.visible = true
	else:
		cerebro = CerebroWallFollower.new()
		overlay_visitadas.visible = false
		overlay_rutas.visible = false

	_visitadas.clear()
	_tiempo_inicio = Time.get_ticks_msec()
	_corrida_activa = true
	_pausado = false
	_fase = Fase.EXPLORANDO
	_pasos_exploracion = 0
	_pasos_speed_run = 0
	_pasos_al_iniciar_speed_run = 0

	btn_pausa.text = "Pausa"
	pantalla_final.visible = false

	paso_timer.wait_time = VELOCIDADES[_idx_vel]
	paso_timer.start()
	fase_cambiada.emit("EXPLORANDO")

	_cargar_record()


func _ready() -> void:
	pasos_cambiados.connect(hud.update_pasos)
	visitadas_cambiadas.connect(hud.update_visitadas)
	fase_cambiada.connect(hud.update_fase)

	raton.choque.connect(func(): sfx_choque.play())
	raton.paso_terminado.connect(func(): sfx_paso.play())

	pantalla_final.visible = false

	_config.load(RECORDS_PATH)
	_poblar_selector()

	_iniciar_corrida()


func _process(_delta: float) -> void:
	if _corrida_activa and not _pausado:
		var segundos = (Time.get_ticks_msec() - _tiempo_inicio) / 1000.0
		hud.update_tiempo(segundos)


func _ejecutar_un_paso() -> void:
	if raton.ocupado():
		return

	match _fase:
		Fase.EXPLORANDO:
			cerebro.paso(raton)
			_visitadas[raton.celda] = true
			pasos_cambiados.emit(raton.pasos)
			visitadas_cambiadas.emit(_visitadas.size())

			if usar_cerebro_estudiante:
				vista_mapa_raton.queue_redraw()
				overlay_visitadas.queue_redraw()

			if laberinto.es_meta(raton.celda):
				_meta_alcanzada()

		Fase.VOLVIENDO:
			cerebro.paso(raton)
			pasos_cambiados.emit(raton.pasos)
			if cerebro._fase == CerebroEstudiante.Fase.SPEED_RUN:
				# capturar pasos en el momento exacto que empieza el speed run
				_pasos_al_iniciar_speed_run = raton.pasos
				_fase = Fase.SPEED_RUN
				fase_cambiada.emit("SPEED RUN")
				overlay_rutas.queue_redraw()

		Fase.SPEED_RUN:
			cerebro.paso(raton)
			pasos_cambiados.emit(raton.pasos)
			overlay_rutas.queue_redraw()
			if laberinto.es_meta(raton.celda):
				# contar solo los pasos del speed run, no los de la vuelta
				_pasos_speed_run = raton.pasos - _pasos_al_iniciar_speed_run
				_meta_alcanzada()

		Fase.FIN:
			paso_timer.stop()


func _on_paso_timer_timeout() -> void:
	_ejecutar_un_paso()


func _meta_alcanzada() -> void:
	match _fase:
		Fase.EXPLORANDO:
			# Primera llegada a la meta
			_pasos_exploracion = raton.pasos
			_fase = Fase.META
			sfx_meta.play()
			fase_cambiada.emit("META")
			print("¡Meta alcanzada en ", _pasos_exploracion, " pasos!")

			if usar_cerebro_estudiante:
				# --- STEP 7 (M3): iniciar vuelta al inicio ---
				cerebro.iniciar_vuelta()
				_fase = Fase.VOLVIENDO
				fase_cambiada.emit("VOLVIENDO")
			else:
				_fase = Fase.FIN
				_corrida_activa = false
				paso_timer.stop()
				fase_cambiada.emit("FIN")
				lbl_resultado_exp.text = "Exploración: %d pasos" % _pasos_exploracion
				lbl_resultado_speed.text = "Speed run: (solo cerebro estudiante)"
				pantalla_final.visible = true
				corrida_terminada.emit(true, _pasos_exploracion, 0)

		Fase.SPEED_RUN:
			# Speed run terminado
			_fase = Fase.FIN
			_corrida_activa = false
			paso_timer.stop()
			fase_cambiada.emit("FIN")
			overlay_rutas.queue_redraw()

			lbl_resultado_exp.text = "Exploración: %d pasos" % _pasos_exploracion
			lbl_resultado_speed.text = "Speed run: %d pasos" % _pasos_speed_run
			pantalla_final.visible = true

			# M4: guardar récord si es mejor
			if _pasos_speed_run > 0:
				_guardar_record_si_mejor(_pasos_speed_run)

			corrida_terminada.emit(true, _pasos_exploracion, _pasos_speed_run)


func _poblar_selector() -> void:
	var selector: OptionButton = $ui/hud/margen/columna/selector_laberinto
	selector.clear()
	var dir = DirAccess.open("res://mazes/")
	if dir == null:
		return
	dir.list_dir_begin()
	var archivos: Array[String] = []
	var nombre = dir.get_next()
	while nombre != "":
		if nombre.ends_with(".maz"):
			archivos.append(nombre)
		nombre = dir.get_next()
	archivos.sort()
	for archivo in archivos:
		selector.add_item(archivo)
		if "res://mazes/" + archivo == archivo_laberinto:
			selector.select(selector.item_count - 1)


func _cargar_record() -> void:
	var rec = _config.get_value("records", archivo_laberinto, -1)
	hud.update_record(rec)


func _guardar_record_si_mejor(pasos: int) -> void:
	var actual = _config.get_value("records", archivo_laberinto, 999999)
	if pasos < actual:
		_config.set_value("records", archivo_laberinto, pasos)
		_config.save(RECORDS_PATH)
		hud.update_record(pasos)


func _on_selector_item_selected(idx: int) -> void:
	var selector: OptionButton = $ui/hud/margen/columna/selector_laberinto
	archivo_laberinto = "res://mazes/" + selector.get_item_text(idx)
	paso_timer.stop()
	_iniciar_corrida()


func _on_boton_pausa_pressed() -> void:
	_pausado = !_pausado
	if _pausado:
		paso_timer.stop()
		btn_pausa.text = "Reanudar"
	else:
		paso_timer.start()
		btn_pausa.text = "Pausa"


func _on_boton_paso_pressed() -> void:
	if _pausado and _corrida_activa:
		_ejecutar_un_paso()


func _on_boton_velocidad_pressed() -> void:
	_idx_vel = (_idx_vel + 1) % VELOCIDADES.size()
	paso_timer.wait_time = VELOCIDADES[_idx_vel]
	raton.duracion_paso = VELOCIDADES[_idx_vel] * 0.8
	btn_velocidad.text = NOMBRES_VEL[_idx_vel]


func _on_boton_reiniciar_pressed() -> void:
	paso_timer.stop()
	_iniciar_corrida()
