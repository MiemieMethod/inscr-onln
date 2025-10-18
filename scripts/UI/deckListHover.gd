extends Button

func hover():
	$"../../../../../Card".draw_from_data(CardInfo.from_name(text))

func _ready():
	Localization.localize_scene(self)

	connect("mouse_entered", self, "hover")
