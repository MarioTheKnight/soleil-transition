## Scene transition manager.
## Handles animated transitions between scenes (fade, etc).
## Call [method to] from anywhere to navigate between scenes.
## [br]
## Usage: [code]SceneTransition.to("res://my_scene.tscn")[/code]
extends CanvasLayer

## Emitted when the transition animation starts (screen goes dark).
signal transition_started

## Emitted when the new scene is fully visible (fade-in complete).
signal transition_finished

## Available transition animation types.
enum TransitionType {
	## Fade to black then fade back in.
	FADE,
	## Immediate scene change with no animation.
	INSTANT,
}

## Default fade duration in seconds.
const DEFAULT_DURATION: float = 0.4

var _overlay: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	# Persist across scene changes.
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## Transitions to [param scene_path] using the given [param type] and [param duration].
## [br]
## [param scene_path]: Absolute resource path to the target scene.
## [param type]: One of [enum TransitionType] values.
## [param duration]: Duration of each half (out + in) in seconds.
## [param stop_music]: If true, fades out music before switching scenes (requires SoleilAudio).
func to(scene_path: String,
		type: TransitionType = TransitionType.FADE,
		duration: float = DEFAULT_DURATION,
		stop_music: bool = false) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()

	match type:
		TransitionType.FADE:
			await _do_fade(scene_path, duration, stop_music)
		TransitionType.INSTANT:
			await _do_instant(scene_path, stop_music)

	transition_finished.emit()
	_is_transitioning = false


## Returns true if a transition is currently in progress.
func is_transitioning() -> bool:
	return _is_transitioning


# ---------------------------------------------------------------------------
# Private — transition implementations
# ---------------------------------------------------------------------------

func _do_fade(scene_path: String, duration: float, stop_music: bool) -> void:
	# Phase 1: fade out to black
	var t_out: Tween = create_tween()
	t_out.tween_property(_overlay, "modulate:a", 1.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await t_out.finished

	# Optionally stop music at the darkest frame
	if stop_music and has_node("/root/SoleilAudio"):
		get_node("/root/SoleilAudio").stop_music(0.01)

	# Phase 2: change scene
	get_tree().change_scene_to_file(scene_path)
	# Yield one frame so the new scene's _ready() fires before fading in
	await get_tree().process_frame

	# Phase 3: fade in from black
	var t_in: Tween = create_tween()
	t_in.tween_property(_overlay, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await t_in.finished


func _do_instant(scene_path: String, stop_music: bool) -> void:
	if stop_music and has_node("/root/SoleilAudio"):
		get_node("/root/SoleilAudio").stop_music(0.01)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
