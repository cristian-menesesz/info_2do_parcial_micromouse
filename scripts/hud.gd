extends PanelContainer

# Panel lateral de telemetría. Las etiquetas ya existen; conéctalas a las
# señales de game.gd, por ejemplo en _ready():
#   var game = get_parent().get_parent()   # CanvasLayer -> Game
#   game.pasos_cambiados.connect(update_pasos)
#   game.fase_cambiada.connect(update_fase)

@onready var fase_label: Label = $margen/columna/fase_label
@onready var pasos_label: Label = $margen/columna/pasos_label
@onready var visitadas_label: Label = $margen/columna/visitadas_label
@onready var tiempo_label: Label = $margen/columna/tiempo_label
@onready var record_label: Label = $margen/columna/record_label


func update_fase(nombre: String) -> void:
	fase_label.text = "fase: %s" % nombre


func update_pasos(pasos: int) -> void:
	pasos_label.text = "pasos: %d" % pasos


func update_visitadas(cantidad: int) -> void:
	visitadas_label.text = "visitadas: %d" % cantidad


func update_tiempo(segundos: float) -> void:
	tiempo_label.text = "tiempo: %.1f s" % segundos


func update_record(pasos: int) -> void:
	# TODO (PARCIAL · M4): mejor marca guardada para el laberinto actual.
	if pasos < 0:
		record_label.text = "récord: —"
	else:
		record_label.text = "récord: %d pasos" % pasos
