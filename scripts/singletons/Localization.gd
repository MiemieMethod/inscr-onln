extends Node

# Localization singleton

var SUPPORTED_LANGS = [
	"en", "zh_CN",
	# "zh_TW", "fr", "it", "de", "es", "pt", "tr", "ru", "ja", "ko"
]

var FALLBACK_LANGS = {
	"zh": "zh_CN",
	"zh_CN": "zh_CN",
	"zh_SG": "zh_CN",
	"zh_TW": "zh_TW",
	"zh_HK": "zh_TW",
	"zh_MO": "zh_TW",
	"en": "en",
	"fr": "fr",
	"it": "it",
	"de": "de",
	"es": "es",
	"pt": "pt",
	"tr": "tr",
	"ru": "ru",
	"ja": "ja",
	"ko": "ko"
}

var font_overrides = {
	"zh_CN": {
		"Marksman": "res://fonts/zh/zpix.ttf",
		"DAGGERSQUARE": "res://fonts/zh/NotoSans_SC.otf",
		"HEAVYWEIGHT": "res://fonts/zh/NotoSerif_SC.otf"
	},
	# add other langs here
}

var lang: String = "en"
var translations := {} # english_string -> translated_string (for current lang)
var ruleset_translations := {}
var overridden_nodes := [] # nodes we applied font override to (weak references)
var extracted_candidates_path := "user://i18n_candidates.json"

var _loaded_font_datas = {}

var I18N_DIR := "res://i18n/"

var _whitespace_regex := RegEx.new()

func _ready():
	get_tree().connect("node_added", self, "_on_node_added")
	get_tree().connect("node_removed", self, "_on_node_removed")
	call_deferred("_apply_to_existing_scene")

static func _detect_best_language() -> String:
	var sys := OS.get_locale()
	for k in Localization.FALLBACK_LANGS.keys():
		if sys.begins_with(k):
			return Localization.FALLBACK_LANGS[k]
	return "en"

func _is_chinese_lang(l: String) -> bool:
	if l == null:
		return false
	return l.begins_with("zh")

func _is_japanese_lang(l: String) -> bool:
	if l == null:
		return false
	return l.begins_with("jp")

func is_chinese_or_japanese_lang(l: String) -> bool:
	return _is_chinese_lang(l) or _is_japanese_lang(l)


func load_language(new_lang: String) -> void:
	lang = new_lang
	_load_project_translations(lang)
	if ruleset_translations.has(lang):
		for k in ruleset_translations[lang].keys():
			translations[k] = ruleset_translations[lang][k]
	apply_language_font_to_current_scene()

func _strip_all_whitespace(s: String) -> String:
	if not _whitespace_regex.is_valid():
		_whitespace_regex.compile("\\s+")
	return _whitespace_regex.sub(s, "", true)

func _load_project_translations(l: String) -> void:
	translations.clear()
	var path := I18N_DIR + l + ".json"
	var f := File.new()
	if f.file_exists(path):
		if f.open(path, File.READ) == OK:
			var j := JSON.parse(f.get_as_text())
			if j.error == OK:
				var raw_trans = j.result
				for k in raw_trans.keys():
					var key_stripped = _strip_all_whitespace(k)
					translations[key_stripped] = raw_trans[k]
			else:
				push_error("Localization: failed to parse %s" % path)
			f.close()

func register_ruleset_translations(rs_trans: Dictionary) -> void:
	for l in rs_trans.keys():
		if not ruleset_translations.has(l):
			ruleset_translations[l] = {}
		for k in rs_trans[l].keys():
			var key_stripped = _strip_all_whitespace(k)
			ruleset_translations[l][key_stripped] = rs_trans[l][k]
	if lang in ruleset_translations:
		for k in ruleset_translations[lang].keys():
			translations[k] = ruleset_translations[lang][k]

func t(key: String, vars: Dictionary = {}) -> String:
	var lookup_key = _strip_all_whitespace(key)
	var s = translations.get(lookup_key, key)
	for k in vars.keys():
		s = s.replace("{%s}" % k, str(vars[k]))
	return s

func _is_numeric_string(s: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^(-|\\d|/)+$")
	return regex.search(s) != null

func _get_font_for(lang_code: String, font_name: String) -> DynamicFontData:
	if not font_overrides.has(lang_code):
		return null
	if not font_overrides[lang_code].has(font_name):
		return null
	var font_path = font_overrides[lang_code][font_name]
	if not _loaded_font_datas.has(font_path):
		var font_data = load(font_path)
		if font_data == null:
			push_error("Localization: font not found at %s" % font_path)
			return null
		_loaded_font_datas[font_path] = font_data
	return _loaded_font_datas[font_path]

func _add_font_override(node: Node):
	if not (node is Control):
		return
	if not font_overrides.has(lang):
		return
	if "text" in node and _is_numeric_string(node.text):
		return
	var font_name = null
	var font_size = null
	if node.get("custom_fonts/font"):
		if node.get("custom_fonts/font").outline_size:
			return
		font_name = "Marksman"
		var old_font_size = node.get("custom_fonts/font").size
		if old_font_size == 64 or old_font_size == 52 or old_font_size == 48:
			font_size = 48
		else:
			font_size = 24
	elif "DAGGERSQUARE" in node.get_theme_default_font().font_data.font_path:
		font_name = "DAGGERSQUARE"
		font_size = node.get_theme_default_font().size
	elif "HEAVYWEIGHT" in node.get_theme_default_font().font_data.font_path:
		font_name = "HEAVYWEIGHT"
		font_size = node.get_theme_default_font().size
	else:
		font_name = "Marksman"
		font_size = 24
	var font_data = _get_font_for(lang, font_name)
	if font_data == null:
		return
	var new_font = DynamicFont.new()
	new_font.font_data = font_data
	new_font.size = font_size
	node.add_font_override("font", new_font)
	overridden_nodes.append(node)

func _apply_font_to_scene(scene):
	if scene == null:
		return
	if not font_overrides.has(lang):
		return
	var list := []
	list.append(scene)
	while list.size() > 0:
		var node = list.pop_back()
		if not is_instance_valid(node):
			continue
		if node is Control:
			_add_font_override(node)
		for c in node.get_children():
			if is_instance_valid(c):
				list.append(c)

func _remove_font_overrides():
	for i in range(overridden_nodes.size()-1, -1, -1):
		var node = overridden_nodes[i]
		if is_instance_valid(node):
			if node.has_method("remove_font_override"):
				node.remove_font_override("font")
		overridden_nodes.remove(i)

func _reapply_font_to_scene(scene):
	_remove_font_overrides()
	if font_overrides.has(lang):
		_apply_font_to_scene(scene)

func _on_node_added(node):
	if font_overrides.has(lang) and node is Control:
		_add_font_override(node)

func _on_node_removed(node):
	for i in range(overridden_nodes.size()-1, -1, -1):
		if overridden_nodes[i] == node:
			overridden_nodes.remove(i)

func apply_language_font_to_current_scene():
	_reapply_font_to_scene(get_tree().get_current_scene())

func _apply_to_existing_scene() -> void:
	var scene = get_tree().get_current_scene()
	if scene:
		call_deferred("_reapply_font_to_scene", scene)

func extract_strings_from_ruleset(ruleset_dat: Dictionary, out_path: String = "") -> Dictionary:
	var out := {}
	out[ruleset_dat.ruleset] = ""
	out[ruleset_dat.description] = ""
	if "cards" in ruleset_dat:
		for c in ruleset_dat.cards:
			if typeof(c) == TYPE_DICTIONARY:
				if c.has("name"):
					out[c.name] = ""
				if c.has("description"):
					out[c.description] = ""
	if "sigils" in ruleset_dat:
		for s_key in ruleset_dat.sigils.keys():
			out[s_key] = ""
			var s_val = ruleset_dat.sigils[s_key]
			if typeof(s_val) == TYPE_DICTIONARY and s_val.has("description"):
				out[s_val.description] = ""
			elif typeof(s_val) == TYPE_STRING:
				out[s_val] = ""
	if "custom_sigils" in ruleset_dat:
		for s_key in ruleset_dat.sigils.keys():
			out[s_key] = ""
			var s_val = ruleset_dat.sigils[s_key]
			if typeof(s_val) == TYPE_DICTIONARY and s_val.has("description"):
				out[s_val.description] = ""
			elif typeof(s_val) == TYPE_STRING:
				out[s_val] = ""
	if "side_decks" in ruleset_dat:
		for d_key in ruleset_dat.side_decks.keys():
			out[d_key] = ""
			var d_val = ruleset_dat.side_decks[d_key]
			if "cards" in d_val and typeof(d_val.cards) == TYPE_DICTIONARY:
				for sub_key in d_val.cards.keys():
					out[sub_key] = ""
	if out_path != "":
		var f = File.new()
		if f.open(out_path, File.WRITE) == OK:
			f.store_string(to_json(out))
			f.close()
	else:
		var f2 = File.new()
		if f2.open(extracted_candidates_path, File.WRITE) == OK:
			f2.store_string(to_json(out))
			f2.close()
	return out

func localize_scene(root: Node) -> void:
	if root == null:
		return
	var stack = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Control and n.hint_tooltip != "":
			n.hint_tooltip = Localization.t(n.hint_tooltip)
		if n is Label or n is Button or n is LineEdit or n is CheckBox:
			if n.text != "":
				n.text = Localization.t(n.text)
		if n is LineEdit:
			if n.placeholder_text != "":
				n.placeholder_text = Localization.t(n.placeholder_text)
		if n is WindowDialog or n is FileDialog:
			if n.window_title != "":
				n.window_title = Localization.t(n.window_title)
		if n is OptionButton or n is PopupMenu:
			for i in range(n.get_item_count()):
				var it = n.get_item_text(i)
				n.set_item_text(i, Localization.t(it))
		if n is TabContainer:
			for i in range(n.get_tab_count()):
				var it = n.get_tab_title(i)
				n.set_tab_title(i, Localization.t(it))
		if n is RichTextLabel:
			if n.bbcode_enabled and n.bbcode_text != "":
				n.bbcode_text = Localization.t(n.bbcode_text)
			elif n.get_text() != "":
				n.set_text(Localization.t(n.get_text()))
