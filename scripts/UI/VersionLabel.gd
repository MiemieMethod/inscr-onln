extends Label


func _ready():
	Localization.localize_scene(self)

	text = CardInfo.VERSION
