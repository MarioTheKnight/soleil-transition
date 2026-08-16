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
## [br]
## Returns [code]false[/code] if another transition was already running and this
## call was refused — callers that care (a menu that must not swallow its own
## button) can react instead of guessing.
func to(scene_path: String,
		type: TransitionType = TransitionType.FADE,
		duration: float = DEFAULT_DURATION,
		stop_music: bool = false) -> bool:
	if _is_transitioning:
		return false
	_is_transitioning = true
	transition_started.emit()

	match type:
		TransitionType.FADE:
			await _do_fade(scene_path, duration, stop_music)
		TransitionType.INSTANT:
			await _do_instant(scene_path, stop_music)

	transition_finished.emit()
	_is_transitioning = false
	return true


## Fades to black, runs [param action] at the darkest frame, then fades back
## in. For host games with a PERSISTENT shell that swaps panel content
## instead of changing the whole scene (the shell never reloads).
## Awaitable. Returns [code]false[/code] if a transition was already in
## progress and this call was refused.
func fade_over(action: Callable,
		duration: float = DEFAULT_DURATION) -> bool:
	if _is_transitioning:
		return false
	_is_transitioning = true
	transition_started.emit()

	var t_out: Tween = _fade_tween(1.0, duration, Tween.EASE_IN)
	await t_out.finished

	if action.is_valid():
		action.call()
	await get_tree().process_frame

	var t_in: Tween = _fade_tween(0.0, duration, Tween.EASE_OUT)
	await t_in.finished

	transition_finished.emit()
	_is_transitioning = false
	return true


## Returns true if a transition is currently in progress.
func is_transitioning() -> bool:
	return _is_transitioning


# ---------------------------------------------------------------------------
# Private — transition implementations
# ---------------------------------------------------------------------------

## A transition tween to [param target_alpha] on the overlay.
## [br]
## [b]Ignores [member Engine.time_scale][/b]: a screen transition is chrome, not
## gameplay. Hostage to time scale, a hit stop (or any slow-motion effect) stalls
## the fade — and because [member _is_transitioning] only clears when the tween
## ends, EVERY later transition is silently refused. A single 0.08s hit stop that
## failed to restore time scale was enough to make a game unnavigable.
func _fade_tween(target_alpha: float, duration: float, ease: Tween.EaseType) -> Tween:
	var tween: Tween = create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_overlay, "modulate:a", target_alpha, duration) \
		.set_ease(ease).set_trans(Tween.TRANS_QUAD)
	return tween


func _do_fade(scene_path: String, duration: float, stop_music: bool) -> void:
	# Phase 1: fade out to black
	var t_out: Tween = _fade_tween(1.0, duration, Tween.EASE_IN)
	await t_out.finished

	# Optionally stop music at the darkest frame
	if stop_music and has_node("/root/SoleilAudio"):
		get_node("/root/SoleilAudio").stop_music(0.01)

	# Phase 2: change scene
	get_tree().change_scene_to_file(scene_path)
	# Yield one frame so the new scene's _ready() fires before fading in
	await get_tree().process_frame

	# Phase 3: fade in from black
	var t_in: Tween = _fade_tween(0.0, duration, Tween.EASE_OUT)
	await t_in.finished


func _do_instant(scene_path: String, stop_music: bool) -> void:
	if stop_music and has_node("/root/SoleilAudio"):
		get_node("/root/SoleilAudio").stop_music(0.01)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
