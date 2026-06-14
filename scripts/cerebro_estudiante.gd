class_name CerebroEstudiante
extends RefCounted

# === TU CEREBRO (M1, M2, M3) ===
#
# Contrato: game.gd llama paso(raton) en cada tick y tu cerebro ejecuta UNA
# acción (girar_izquierda / girar_derecha / avanzar). Solo puedes usar la API
# pública del ratón — sensar paredes de la celda actual y moverte. Nada de
# leer el laberinto real.
#
# Para activarlo: en el Inspector de la escena game.tscn, marca la casilla
# "Usar Cerebro Estudiante" del nodo raíz (o cambia el valor por defecto en
# game.gd).
#
# Plan sugerido (es el algoritmo clásico de la competencia micromouse):
#
#   FASE 1 — EXPLORAR (M1):
#     - Mantén tu propio mapa: un Laberinto.vacio(ancho, alto) donde anotas
#       (con poner_pared) cada pared que sensas, y un diccionario de celdas
#       visitadas. El ratón conoce su celda y rumbo (raton.celda, raton.rumbo).
#     - Flood-fill: calcula la distancia de CADA celda a la meta inundando
#       desde la meta sobre tu mapa (las celdas no exploradas se asumen sin
#       paredes — por eso se vuelve a calcular cada vez que descubres una).
#     - Muévete siempre hacia la celda vecina accesible con menor distancia.
#     - Cuando llegues a la meta, puedes seguir explorando o volver al inicio.
#
#   FASE 2 — SPEED RUN (M3):
#     - De vuelta en el inicio, calcula la mejor ruta sobre el mapa que
#       DESCUBRISTE (otro flood-fill, esta vez solo por celdas conocidas) y
#       ejecútala sin sensar. Compárala en pantalla con la ruta de exploración.
#
#   El mapa que mantienes aquí es exactamente lo que la vista "mapa del ratón"
#   (M2) debe dibujar: expón tu Laberinto descubierto y tus visitadas para que
#   game.gd se los pase a la vista derecha.

var ancho: int = 0
var alto: int = 0
var metas: Array[Vector2i] = []
var inicio: Vector2i = Vector2i.ZERO

enum Fase { EXPLORANDO, VOLVIENDO, SPEED_RUN }
var _fase: Fase = Fase.EXPLORANDO

var _mapa: Laberinto = null
var _visitadas: Dictionary = {}
var _distancias: Array = []

var _ruta_exploracion: Array[Vector2i] = []
var _ruta_speed_run: Array[Vector2i] = []
var _idx_speed: int = 0


func get_mapa() -> Laberinto:
	return _mapa

func get_visitadas() -> Dictionary:
	return _visitadas

func ruta_exploracion() -> Array[Vector2i]:
	return _ruta_exploracion

func ruta_speed_run() -> Array[Vector2i]:
	return _ruta_speed_run


func preparar(ancho_: int, alto_: int, metas_: Array[Vector2i],
		inicio_: Vector2i = Vector2i.ZERO) -> void:
	ancho = ancho_
	alto = alto_
	metas = metas_
	inicio = inicio_
	# Mapa vacío: solo bordes exteriores, sin paredes internas (lo que el ratón
	# aún no ha sensado se trata como paso libre — optimista por defecto).
	_mapa = Laberinto.vacio(ancho, alto)
	_mapa.inicio = inicio
	_mapa.metas = metas.duplicate()

	_visitadas.clear()

	_ruta_exploracion.clear()
	_ruta_speed_run.clear()
	_idx_speed = 0

	_fase = Fase.EXPLORANDO
	_flood_fill(metas, false)

func paso(raton: Raton) -> void:
	match _fase:
		Fase.EXPLORANDO:
			_paso_explorando(raton)
		Fase.VOLVIENDO:
			_paso_volviendo(raton)
		Fase.SPEED_RUN:
			_paso_speed_run(raton)


func _paso_explorando(raton: Raton) -> void:
	# 1. Sensar y anotar paredes de la celda actual
	_anotar_paredes(raton)

	# 2. Registrar celda visitada
	if not _visitadas.has(raton.celda):
		_visitadas[raton.celda] = true
		_ruta_exploracion.append(raton.celda)

	# 3. Recalcular flood-fill (las paredes nuevas pueden cambiar distancias)
	_flood_fill(metas, false)

	# 4. Girar/avanzar hacia la vecina con menor distancia
	_mover_hacia_menor_distancia(raton)


func _anotar_paredes(raton: Raton) -> void:
	# Mapeamos los tres sensores al rumbo absoluto correspondiente y anotamos
	# en nuestro mapa descubierto.
	var dir_frente = raton.rumbo
	var dir_izquierda = (raton.rumbo + 3) % 4
	var dir_derecha = (raton.rumbo + 1) % 4

	if raton.pared_frente():
		_mapa.poner_pared(raton.celda, dir_frente)
	if raton.pared_izquierda():
		_mapa.poner_pared(raton.celda, dir_izquierda)
	if raton.pared_derecha():
		_mapa.poner_pared(raton.celda, dir_derecha)

	# La pared de atrás no se puede sensar directamente con la API provista,
	# pero se puede inferir si venimos de otra celda (aquí se omite para
	# no complicar el primer paso; flood-fill optimista maneja el resto).


func _mover_hacia_menor_distancia(raton: Raton) -> void:
	var rumbo_objetivo = _mejor_rumbo(raton.celda, raton.rumbo)

	if rumbo_objetivo == -1:
		raton.girar_derecha()
		return

	# Si ya apuntamos al objetivo → avanzar.
	# Si no → solo girar (avanzar ocurrirá en el siguiente tick).
	if raton.rumbo == rumbo_objetivo:
		raton.avanzar()
	else:
		_girar_hacia(raton, rumbo_objetivo)


func _mejor_rumbo(desde: Vector2i, _rumbo_actual: int) -> int:
	var mejor_dir = -1
	var mejor_dist = INF

	for dir in range(4):
		if _mapa.tiene_pared(desde, dir):
			continue

		var vecina = desde + Laberinto.DELTAS[dir]

		if not _mapa.en_rango(vecina):
			continue

		var d = _distancias[vecina.y][vecina.x]

		if d < mejor_dist:
			mejor_dist = d
			mejor_dir = dir

	return mejor_dir


func _girar_hacia(raton: Raton, rumbo_objetivo: int) -> void:
	if raton.rumbo == rumbo_objetivo:
		return

	var diff = (rumbo_objetivo - raton.rumbo + 4) % 4

	if diff == 1:
		raton.girar_derecha()
	elif diff == 3:
		raton.girar_izquierda()
	else:
		raton.girar_derecha()


func _flood_fill(hasta: Array[Vector2i], solo_conocidas: bool) -> void:
	_distancias.clear()

	for _y in alto:
		var fila = []
		fila.resize(ancho)
		fila.fill(999999)
		_distancias.append(fila)

	var cola: Array[Vector2i] = []

	for meta in hasta:
		if _mapa.en_rango(meta):
			_distancias[meta.y][meta.x] = 0
			cola.append(meta)

	var i = 0

	while i < cola.size():
		var actual = cola[i]
		i += 1

		var dist_actual = _distancias[actual.y][actual.x]

		for dir in range(4):
			if _mapa.tiene_pared(actual, dir):
				continue

			var vecina = actual + Laberinto.DELTAS[dir]

			if not _mapa.en_rango(vecina):
				continue

			if solo_conocidas and not _visitadas.has(vecina):
				continue

			if _distancias[vecina.y][vecina.x] > dist_actual + 1:
				_distancias[vecina.y][vecina.x] = dist_actual + 1
				cola.append(vecina)


func iniciar_vuelta() -> void:
	_fase = Fase.VOLVIENDO
	# solo_conocidas=true — la vuelta solo usa celdas visitadas,
	# nunca atraviesa zonas no exploradas cuyas paredes son desconocidas.
	_flood_fill([inicio], true)

func _paso_volviendo(raton: Raton) -> void:
	if raton.celda == inicio:
		_calcular_ruta_speed_run()
		_fase = Fase.SPEED_RUN
		return

	_mover_hacia_menor_distancia(raton)

func _calcular_ruta_speed_run() -> void:
	_flood_fill(metas, true)

	_ruta_speed_run.clear()

	var celda_actual = inicio

	_ruta_speed_run.append(celda_actual)

	var max_iter = ancho * alto

	while not _mapa.es_meta(celda_actual) and max_iter > 0:
		max_iter -= 1

		var mejor_dir = _mejor_rumbo(celda_actual, 0)

		if mejor_dir == -1:
			break

		celda_actual += Laberinto.DELTAS[mejor_dir]

		_ruta_speed_run.append(celda_actual)

func iniciar_speed_run() -> void:
	_fase = Fase.SPEED_RUN
	_idx_speed = 0
	_flood_fill(metas, true)

func _paso_speed_run(raton: Raton) -> void:
	if _idx_speed >= _ruta_speed_run.size() - 1:
		return

	var celda_destino = _ruta_speed_run[_idx_speed + 1]

	var dir_hacia = _direccion_entre(
		raton.celda,
		celda_destino
	)

	if dir_hacia == -1:
		return

	# una sola acción por tick.
	if raton.rumbo == dir_hacia:
		if raton.avanzar():
			_idx_speed += 1
	else:
		_girar_hacia(raton, dir_hacia)

func _direccion_entre(desde: Vector2i, hasta: Vector2i) -> int:
	var delta = hasta - desde

	for dir in range(4):
		if Laberinto.DELTAS[dir] == delta:
			return dir

	return -1