extends Node2D

# Overlay que se dibuja ENCIMA de vista_mapa_raton y colorea:
# - celdas visitadas: tinte azul claro
# - celdas no visitadas: sin tinte (fondo oscuro visible por defecto)
#
# game.gd llama queue_redraw() en cada tick para mantenerlo actualizado.
# Debe estar posicionado en x=672 (igual que vista_mapa_raton) en la escena.

var cerebro = null      # referencia a CerebroEstudiante, asignada por game.gd
var origen: Vector2 = Vector2.ZERO
var tam: float = 38.0

# Color de relleno para celdas visitadas
const COLOR_VISITADA = Color(0.25, 0.55, 1.0, 0.22)
const COLOR_ACTUAL   = Color(1.0,  0.85, 0.2, 0.45)  # celda donde está el ratón ahora


func configurar(cerebro_: Object, origen_: Vector2, tam_: float) -> void:
	cerebro = cerebro_
	origen = origen_
	tam = tam_
	queue_redraw()


func _draw() -> void:
	if cerebro == null:
		return

	var visitadas = cerebro.get_visitadas()
	for celda in visitadas:
		var rect = Rect2(origen + Vector2(celda) * tam, Vector2(tam, tam))
		draw_rect(rect, COLOR_VISITADA)
