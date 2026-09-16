# Authored by Max Royer

extends Node3D

@onready var reset_timer: Timer = $ResetTimer
@onready var kickout_timer: Timer = $KickoutTimer


@onready var score_label: Label3D = $ScoreLabel

var score := 0

var prev_object

func entered_goal(object: Variant) -> void:
	print("SOMETHING WENT IN THE GOAL: " + str(object))

	prev_object = object
	kickout_timer.start()
	
	if object is SoccerBall:
		# only real goals keep the score alive
		reset_timer.start()
		update_score(score + 1)
		

func update_score(new_score):
	print("set score to " + str(new_score))
	score = new_score
	score_label.text = str(score)



func _on_reset_timer_timeout() -> void:
	update_score(0)


func _on_kickout_timer_timeout() -> void:
	prev_object.apply_impulse(Vector3(40, 40, 0))
	prev_object = null
	kickout_timer.stop()
	
