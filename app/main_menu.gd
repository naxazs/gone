class_name MainMenu
extends Control
## Opening title screen. A robot peers through a door it has pulled open:
## one intact eye tracks the pointer while its other socket hangs cracked
## and dead, until the player chooses to wake.

signal play_requested
signal quit_requested

const FACE_SIZE := Vector2(380.0, 240.0)
const EYE_SIZE := Vector2(112.0, 58.0)
const EYE_SPACING: float = 76.0
const PUPIL_RADIUS: float = 11.0
const PUPIL_TRAVEL: float = 18.0
const BUTTON_SIZE := Vector2(260.0, 52.0)

var _pointer: Vector2 = Vector2.ZERO
var _start_button: Button
var _quit_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_pointer = get_viewport_rect().size * 0.5
	_build_interface()
	_start_button.grab_focus()
	queue_redraw()

func _process(_delta: float) -> void:
	var pointer := get_local_mouse_position()
	if pointer != _pointer:
		_pointer = pointer
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		quit_requested.emit()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color("020405"))
	# Shallow bands keep the black field from reading as a flat UI card.
	for band: int in range(8):
		var shade := 0.012 + float(band) * 0.003
		draw_rect(Rect2(0.0, float(band) * size.y / 8.0, size.x, size.y / 8.0),
			Color(shade, shade * 1.08, shade * 1.12))
	var center := size * Vector2(0.5, 0.30)
	_draw_open_door(center)
	_draw_robot_face(center)

## Two heavy leaves angle away from the center aperture. Their inner red
## seams frame the face and sell the instant after the robot opened them.
func _draw_open_door(center: Vector2) -> void:
	var aperture_half := Vector2(FACE_SIZE.x * 0.70, FACE_SIZE.y * 0.72)
	var top := center.y - aperture_half.y
	var bottom := center.y + aperture_half.y
	var left_edge := center.x - aperture_half.x
	var right_edge := center.x + aperture_half.x
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, top - 55.0), Vector2(left_edge, top),
		Vector2(left_edge - 38.0, bottom), Vector2(0.0, bottom + 80.0),
	]), Color("111619"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x, top - 55.0), Vector2(right_edge, top),
		Vector2(right_edge + 38.0, bottom), Vector2(size.x, bottom + 80.0),
	]), Color("111619"))
	draw_line(Vector2(left_edge, top), Vector2(left_edge - 38.0, bottom), Color("7f1f25"), 5.0)
	draw_line(Vector2(right_edge, top), Vector2(right_edge + 38.0, bottom), Color("7f1f25"), 5.0)
	for offset: float in [42.0, 88.0, 134.0]:
		draw_line(Vector2(left_edge - offset, top + 8.0),
			Vector2(left_edge - offset - 22.0, bottom - 10.0), Color("242b2e"), 2.0)
		draw_line(Vector2(right_edge + offset, top + 8.0),
			Vector2(right_edge + offset + 22.0, bottom - 10.0), Color("242b2e"), 2.0)

func _draw_robot_face(center: Vector2) -> void:
	var half := FACE_SIZE * 0.5
	var face := PackedVector2Array([
		center + Vector2(-half.x * 0.72, -half.y),
		center + Vector2(half.x * 0.72, -half.y),
		center + Vector2(half.x, -half.y * 0.38),
		center + Vector2(half.x * 0.86, half.y * 0.58),
		center + Vector2(half.x * 0.46, half.y),
		center + Vector2(-half.x * 0.46, half.y),
		center + Vector2(-half.x * 0.86, half.y * 0.58),
		center + Vector2(-half.x, -half.y * 0.38),
	])
	draw_colored_polygon(face, Color("252b2d"))
	draw_polyline(face, Color("687074"), 4.0, true)
	# Brow plates, cheek seams, and a narrow mouth grille make a face
	# without revealing any body behind the doorway.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-145.0, -70.0), center + Vector2(-42.0, -100.0),
		center + Vector2(-55.0, -50.0), center + Vector2(-150.0, -35.0),
	]), Color("353d40"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(145.0, -70.0), center + Vector2(42.0, -100.0),
		center + Vector2(55.0, -50.0), center + Vector2(150.0, -35.0),
	]), Color("353d40"))
	draw_line(center + Vector2(-150.0, 36.0), center + Vector2(-72.0, 82.0), Color("596164"), 3.0)
	draw_line(center + Vector2(150.0, 36.0), center + Vector2(72.0, 82.0), Color("596164"), 3.0)
	draw_rect(Rect2(center + Vector2(-70.0, 74.0), Vector2(140.0, 22.0)), Color("080b0c"))
	for slot: int in range(7):
		var x := center.x - 54.0 + float(slot) * 18.0
		draw_line(Vector2(x, center.y + 78.0), Vector2(x, center.y + 91.0), Color("394144"), 3.0)
	_draw_eye(center + Vector2(-EYE_SPACING, -18.0))
	_draw_broken_eye(center + Vector2(EYE_SPACING, -18.0))

func _draw_eye(center: Vector2) -> void:
	var tracking := pupil_offset(center, _pointer)
	draw_set_transform(center)
	_draw_eye_shape(Vector2.ZERO, EYE_SIZE * 0.5, Color("aeb9ba"))
	draw_polyline(PackedVector2Array([
		Vector2(-EYE_SIZE.x * 0.52, 0.0), Vector2(0.0, -EYE_SIZE.y * 0.62),
		Vector2(EYE_SIZE.x * 0.52, 0.0), Vector2(0.0, EYE_SIZE.y * 0.62),
	]), Color("8e252c"), 4.0, true)
	draw_circle(tracking, PUPIL_RADIUS + 8.0, Color("781d23"))
	draw_circle(tracking, PUPIL_RADIUS, Color("030505"))
	draw_circle(tracking + Vector2(-3.0, -3.0), 2.5, Color(0.9, 0.93, 0.9, 0.8))
	draw_set_transform(Vector2.ZERO)

## The second eye is physically present but destroyed: a dark socket,
## displaced lens fragment, and asymmetrical fracture lines make the
## failure legible instead of looking like a closed eyelid.
func _draw_broken_eye(center: Vector2) -> void:
	draw_set_transform(center)
	_draw_eye_shape(Vector2.ZERO, EYE_SIZE * 0.5, Color("171b1c"))
	draw_circle(Vector2(8.0, 7.0), PUPIL_RADIUS + 10.0, Color("080a0a"))
	draw_circle(Vector2(13.0, 12.0), PUPIL_RADIUS - 3.0, Color("431116"))
	for fracture: PackedVector2Array in [
		PackedVector2Array([Vector2(-54.0, -2.0), Vector2(-25.0, 4.0), Vector2(-8.0, 21.0)]),
		PackedVector2Array([Vector2(-7.0, -27.0), Vector2(2.0, -9.0), Vector2(27.0, 1.0)]),
		PackedVector2Array([Vector2(4.0, -7.0), Vector2(34.0, -21.0), Vector2(55.0, -13.0)]),
		PackedVector2Array([Vector2(1.0, 8.0), Vector2(25.0, 27.0), Vector2(44.0, 22.0)]),
	]:
		draw_polyline(fracture, Color("8e252c"), 3.0, true)
	draw_set_transform(Vector2.ZERO)

static func pupil_offset(eye_center: Vector2, pointer: Vector2) -> Vector2:
	var direction := (pointer - eye_center).normalized()
	var distance := eye_center.distance_to(pointer)
	return direction * minf(PUPIL_TRAVEL, distance * 0.055)

func _draw_eye_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(49):
		var angle := TAU * float(index) / 48.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
	draw_polyline(points, Color("5c1013"), 2.0, true)

func _build_interface() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position = Vector2(-BUTTON_SIZE.x * 0.5, 60.0)
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var title := Label.new()
	title.text = "G O N E"
	title.custom_minimum_size = Vector2(BUTTON_SIZE.x, 72.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("b9aaa4"))
	column.add_child(title)

	_start_button = _menu_button("DESPERTAR")
	_start_button.pressed.connect(func() -> void: play_requested.emit())
	column.add_child(_start_button)

	_quit_button = _menu_button("ABANDONAR")
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	column.add_child(_quit_button)

	var hint := Label.new()
	hint.text = "FLECHAS / RATÓN     ESPACIO / CLIC     ESC SALIR"
	hint.custom_minimum_size = Vector2(BUTTON_SIZE.x, 36.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("5d5d5d"))
	column.add_child(hint)

func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("8e8582"))
	button.add_theme_color_override("font_hover_color", Color("e0d6cf"))
	button.add_theme_color_override("font_focus_color", Color("e0d6cf"))
	button.add_theme_color_override("font_pressed_color", Color("a92b30"))
	button.add_theme_stylebox_override("normal", _button_style(Color("090a0b"), Color("242426"), 1))
	button.add_theme_stylebox_override("hover", _button_style(Color("111011"), Color("681b20"), 2))
	button.add_theme_stylebox_override("focus", _button_style(Color("111011"), Color("681b20"), 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color("180b0d"), Color("9a282e"), 2))
	return button

func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
