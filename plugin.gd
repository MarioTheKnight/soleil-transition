@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_autoload_singleton("SceneTransition",
		"res://addons/soleil_transition/autoloads/scene_transition.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("SceneTransition")
