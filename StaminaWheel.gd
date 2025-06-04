extends TextureProgressBar

# Fade parameters (optional for smoothness)
@export var fade_speed := 6.0

var target_visible := false

func _ready():
	# Connect to the Player's stamina_changed signal
	var player = get_tree().get_root().find_child("Player", true, false)
	if player:
		player.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
	else:
		push_warning("Player node not found!")

	self.modulate.a = 0.0
	visible = true # Keep visible so modulate works

func _on_stamina_changed(stamina_value: float, stamina_maximum: float):
	self.max_value = stamina_maximum
	self.value = stamina_value

	# Show stamina wheel if sprinting (shift), or stamina is not full (regenerating)
	var shift_held = Input.is_action_pressed("sprint")
	target_visible = shift_held or stamina_value < stamina_maximum

func _process(delta):
	# Fade in/out for smoothness
	var target_alpha = 1.0 if target_visible else 0.0
	self.modulate.a = lerp(self.modulate.a, target_alpha, delta * fade_speed)
