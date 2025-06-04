extends TextureProgressBar

@export var fade_speed := 6.0

var target_visible := false
var _locked_empty := false  # Internal state for hysteresis

const EMPTY_THRESHOLD := 3.0
const RELEASE_THRESHOLD := 4.0  # Must be > EMPTY_THRESHOLD

func _ready():
	var player = get_tree().get_root().find_child("Player", true, false)
	if player:
		player.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
	else:
		push_warning("Player node not found!")

	self.modulate.a = 0.0
	visible = true

func _on_stamina_changed(stamina_value: float, stamina_maximum: float):
	self.max_value = stamina_maximum

	# Flicker-free hysteresis logic
	if _locked_empty:
		if stamina_value > RELEASE_THRESHOLD:
			_locked_empty = false
	else:
		if stamina_value <= EMPTY_THRESHOLD:
			_locked_empty = true

	if _locked_empty:
		self.value = 0.0
	else:
		self.value = stamina_value

	var shift_held = Input.is_action_pressed("sprint")
	target_visible = shift_held or stamina_value < stamina_maximum

func _process(delta):
	var target_alpha = 1.0 if target_visible else 0.0
	self.modulate.a = lerp(self.modulate.a, target_alpha, delta * fade_speed)
