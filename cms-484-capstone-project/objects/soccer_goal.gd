# Authored by Max Royer

extends Node3D

## Networking model: only the host detects goals, keeps score, and runs the
## timers. Clients switch those off in setup_network(). The score reaches
## everyone through the MultiplayerSynchronizer on ScoreLabel:text, so on a
## client the `score` variable itself stays unused.

@onready var reset_timer: Timer = $ResetTimer
@onready var kickout_timer: Timer = $KickoutTimer
@onready var score_label: Label3D = $ScoreLabel
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var score := 0

var prev_object: RigidBody3D = null

func entered_goal(object: Variant) -> void:
	print("SOMETHING WENT IN THE GOAL: " + str(object))

	if object is RigidBody3D:
		prev_object = object
		kickout_timer.start()

	if object is SoccerBall:
		# only real goals keep the score alive
		reset_timer.start()
		update_score(score + 1)


func update_score(new_score: int) -> void:
	print("set score to " + str(new_score))
	score = new_score
	score_label.text = str(score)


func _on_reset_timer_timeout() -> void:
	update_score(0)


func _on_kickout_timer_timeout() -> void:
	# The object may have been freed while the timer was running.
	if is_instance_valid(prev_object):
		# Rotated with the goal, so a second goal facing the other way kicks
		# the ball out of its own mouth instead of into its back net.
		prev_object.apply_impulse(global_basis * Vector3(40, 40, 0))
	prev_object = null


## Called by MultiplayerTestRoom.initialize() via the "networked" group.
func setup_network() -> void:
	if is_multiplayer_authority():
		return
	# Deferred so this is safe even if a physics query is in progress.
	hitbox_component.set_deferred("monitoring", false)
	reset_timer.stop()
	kickout_timer.stop()


## Called by MultiplayerTestRoom.teardown() when leaving a session.
func teardown_network() -> void:
	hitbox_component.set_deferred("monitoring", true)
	kickout_timer.stop()
	prev_object = null
	reset_timer.start()
	update_score(0)
