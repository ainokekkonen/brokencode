
# ParallaxAutoMirrorStable.gd
# Attach this to your ParallaxBackground.
# It auto-computes motion_mirroring for all child ParallaxLayers and stabilizes wrapping to avoid seams.
@tool
extends ParallaxBackground

@export var enable_vertical_mirroring: bool = false
@export var auto_update_in_editor: bool = true
@export var overlap_px: int = 2                 # extra pixels to hide rounding seams
@export var snap_motion_offset: bool = true     # snap per-layer offset to integer pixels

var _needs_recompute := false
var _layers: Array[ParallaxLayer] = []

func _ready() -> void:
	_collect_layers()
	_recompute_all_layers()

func _process(_delta: float) -> void:
	# Editor auto-update
	if Engine.is_editor_hint() and auto_update_in_editor and _needs_recompute:
		_needs_recompute = false
		_collect_layers()
		_recompute_all_layers()

	# Runtime snapping (prevents subpixel drift gaps when camera smoothing is on)
	if snap_motion_offset:
		for layer in _layers:
			layer.motion_offset = Vector2(floor(layer.motion_offset.x), floor(layer.motion_offset.y))

func _notification(what: int) -> void:
	if Engine.is_editor_hint() and auto_update_in_editor:
		match what:
			NOTIFICATION_CHILD_ORDER_CHANGED, NOTIFICATION_POST_ENTER_TREE:
				_schedule_recompute()

func _schedule_recompute() -> void:
	_needs_recompute = true

func _collect_layers() -> void:
	_layers.clear()
	_collect_layers_recursive(self)

func _collect_layers_recursive(root: Node) -> void:
	for child in root.get_children():
		if child is ParallaxLayer:
			_layers.append(child as ParallaxLayer)
		elif child.get_child_count() > 0:
			_collect_layers_recursive(child)

func _recompute_all_layers() -> void:
	for layer in _layers:
		_configure_layer(layer)

func _configure_layer(layer: ParallaxLayer) -> void:
	var rect := _compute_content_rect(layer)
	if rect.size == Vector2.ZERO:
		layer.push_warning("AutoMirror: No Sprite2D with textures found in '%s'." % layer.name)
		return

	# Round to integer pixels and add a small overlap to avoid precision/rounding seams.
	var mirror_x := int(round(rect.size.x)) - overlap_px
	var mirror_y := int(round(rect.size.y)) - overlap_px

	if mirror_x < 1:
		mirror_x = 0
	if not enable_vertical_mirroring:
		mirror_y = 0
	elif mirror_y < 1:
		mirror_y = 0

	layer.motion_mirroring = Vector2(mirror_x, mirror_y)

func _compute_content_rect(layer: ParallaxLayer) -> Rect2:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	for child in layer.get_children():
		if child is Sprite2D:
			var spr := child as Sprite2D
			if spr.texture == null:
				continue

			var tex_size: Vector2 = spr.texture.get_size()
			var w := tex_size.x * spr.scale.x
			var h := tex_size.y * spr.scale.y

			# Correct GDScript ternary form:
			var offset := (Vector2(w * 0.5, h * 0.5) if spr.centered else Vector2.ZERO)
			var left := spr.position.x - offset.x
			var top  := spr.position.y - offset.y
			var right := left + w
			var bottom := top + h

			min_x = min(min_x, left)
			max_x = max(max_x, right)
			min_y = min(min_y, top)
			max_y = max(max_y, bottom)

	if min_x == INF:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
