extends WindowDialog

var LANG_DISPLAY_NAMES = {
	"en": "English",
	"zh_CN": "简体中文",
	"zh_TW": "繁體中文",
	"fr": "Français",
	"it": "Italiano",
	"de": "Deutsch",
	"es": "Español",
	"pt": "Português",
	"tr": "Türkçe",
	"ru": "Русский",
	"ja": "日本語",
	"ko": "한국어"
}

func update_options():
	for cat in $TabContainer.get_children():
		for opt in cat.get_children():
			if opt.name in GameOptions.options:
				
				var old_val = GameOptions.options[opt.name]
				
				if old_val != opt.pressed:
					continue
					
				GameOptions.options[opt.name] = not opt.pressed
				
				# Reload deck editor
				if opt.name in ["enable_accessibility_icons", "show_card_tooltips", "show_banned"]:
					get_node("/root/Main/DeckEdit").search()
				
				# Stretch screen
				if opt.name == "stretch_to_fill":
			#		get_viewport().size = OS.window_size
					if GameOptions.options.stretch_to_fill:
						get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_IGNORE, Vector2(1920, 1080))
					else:
						get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP, Vector2(1920, 1080))
					
				if opt.name == "fullscreen":
					OS.window_fullscreen = GameOptions.options.fullscreen
				
				if opt.name == "crt_filter":
					get_node("/root/Main/Scanlines").visible = GameOptions.options.crt_filter

				if opt.name == "enable_sfx":
					AudioServer.set_bus_mute(2, not GameOptions.options.enable_sfx)
				if opt.name == "enable_music":
					AudioServer.set_bus_mute(1, not GameOptions.options.enable_music)
				
				if opt.name == "vsync":
					OS.vsync_enabled = GameOptions.options.vsync
					
				if opt.name == "lock_fps":
					Engine.target_fps = 60 if GameOptions.options.lock_fps else 0
				
func update_controls():
	for cat in $TabContainer.get_children():
		for opt in cat.get_children():
			if opt.name in GameOptions.options:
				opt.pressed = not GameOptions.options[opt.name]
	var lang_opt = find_node("LanguageOption", true, false)
	if lang_opt:
		lang_opt.clear()
		for l in Localization.SUPPORTED_LANGS:
			lang_opt.add_item(LANG_DISPLAY_NAMES.get(l, l))
		var cur_lang = GameOptions.options.language
		var idx = Localization.SUPPORTED_LANGS.find(cur_lang)
		if idx == -1:
			idx = 0
		lang_opt.select(idx)

func connect_signals():
	for cat in $TabContainer.get_children():
		for opt in cat.get_children():
			if opt.name in GameOptions.options:
				opt.connect("pressed", self, "update_options")
	var lang_opt = find_node("LanguageOption", true, false)
	if lang_opt:
		if lang_opt.is_connected("item_selected", self, "_on_LanguageOption_item_selected"):
			lang_opt.disconnect("item_selected", self, "_on_LanguageOption_item_selected")
		lang_opt.connect("item_selected", self, "_on_LanguageOption_item_selected")

func _ready():
	Localization.localize_scene(self)
	
	update_controls()
	connect_signals()
	
	# Apply options
	get_node("/root/Main/Scanlines").visible = GameOptions.options.crt_filter
	AudioServer.set_bus_mute(1, not GameOptions.options.enable_music)
	AudioServer.set_bus_mute(2, not GameOptions.options.enable_sfx)
	
	
func _on_LanguageOption_item_selected(index):
	var new_lang = Localization.SUPPORTED_LANGS[index]
	GameOptions.options.language = new_lang
	GameOptions.save_options()
	Localization.load_language(new_lang)
			
	get_tree().reload_current_scene()
