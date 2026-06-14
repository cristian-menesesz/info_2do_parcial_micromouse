extends Node2D

# Overlay sobre la vista de dios que dibuja dos rutas superpuestas (M3):
# - naranja semitransparente: camino recorrido durante la exploración
# - verde brillante: ruta óptima del speed run
#
# Se dibuja sobre la vista de dios (posición 0,0 en la escena).
# game.gd llama queue_redraw() al entrar en SPEED_RUN y en FIN.

var cerebro = null
var origen: Vector2 = Vector2.ZERO
var tam: float = 38.0

const COLOR_EXPLORACION = Color(1.0, 0.55, 0.05, 0.50)   # naranja
const COLOR_SPEED_RUN   = Color(0.15, 1.0,  0.35, 0.80)  # verde
const GROSOR_EXP   = 2.0
const GROSOR_SPEED = 3.0


func configurar(cerebro_: Object, origen_: Vector2, tam_: float) -> void:
	cerebro = cerebro_
	origen = origen_
	tam = tam_
	queue_redraw()


func _celda_centro(celda: Vector2i) -> Vector2:
	return origen + (Vector2(celda) + Vector2(0.5, 0.5)) * tam


func _draw() -> void:
	if cerebro == null:
		return

	# Ruta de exploración (naranja)
	var ruta_exp = cerebro.ruta_exploracion()
	for i in range(1, ruta_exp.size()):
		draw_line(_celda_centro(ruta_exp[i - 1]), _celda_centro(ruta_exp[i]),
				COLOR_EXPLORACION, GROSOR_EXP)

	# Ruta del speed run (verde, encima)
	var ruta_speed = cerebro.ruta_speed_run()
	for i in range(1, ruta_speed.size()):
		draw_line(_celda_centro(ruta_speed[i - 1]), _celda_centro(ruta_speed[i]),
				COLOR_SPEED_RUN, GROSOR_SPEED)
