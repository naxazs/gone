class_name SurvivalHUD
extends CanvasLayer
## Urgency layer for the opening escape: the survivor wakes poisoned,
## sees the remaining clean-air window, and receives a terminal death
## card if the stasis bay is not cleared before the logical clock ends.

const LAYER_ORDER: int = 110
const POISON_COLOR := Color(0.47, 0.92, 0.38)

var _game: Game
var _poison_wash: ColorRect
var _status: Label
var _death_panel: ColorRect

static func build(game: Game) -> SurvivalHUD:
	var hud := SurvivalHUD.new()
	hud.name = "SurvivalHUD"
	hud.layer = LAYER_ORDER
	hud._game = game
	hud._build_interface()
	return hud

func _process(_delta: float) -> void:
	if _game == null:
		return
	var poisoned := _game.is_poisoned()
	_poison_wash.visible = poisoned
	_status.visible = poisoned
	if poisoned:
		_status.text = "ENVENENADO  ·  SAL DE LA CÁMARA  ·  %02d s" % _game.poison_seconds_remaining()
	_death_panel.visible = _game.is_dead()
	if _game.is_dead():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_interface() -> void:
	_poison_wash = ColorRect.new()
	_poison_wash.name = "PoisonWash"
	_poison_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_poison_wash.color = Color(0.08, 0.24, 0.04, 0.09)
	_poison_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_poison_wash)

	_status = Label.new()
	_status.name = "PoisonStatus"
	_status.position = Vector2(24.0, 20.0)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", POISON_COLOR)
	_status.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	_death_panel = ColorRect.new()
	_death_panel.name = "DeathPanel"
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.color = Color(0.12, 0.0, 0.01, 0.92)
	_death_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_panel.visible = false
	add_child(_death_panel)

	var death_text := Label.new()
	death_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_text.position = Vector2(-260.0, -80.0)
	death_text.custom_minimum_size = Vector2(520.0, 160.0)
	death_text.text = "HAS MUERTO\nEL VENENO HA COLAPSADO TU CUERPO\n\nESC  SALIR"
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_text.add_theme_font_size_override("font_size", 22)
	death_text.add_theme_color_override("font_color", Color("d8c7c1"))
	_death_panel.add_child(death_text)
