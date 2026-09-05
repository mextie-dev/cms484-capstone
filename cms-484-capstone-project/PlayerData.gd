extends Node

## base player info, needs
var player_name := "default"
var player_display_level : String
var player_tag : String

var player_message_color := Color(randf(), randf(), randf())

## player unlocks
var player_unlocked_cosmetics := []
var player_unlocked_tags := []

## player levelling
var player_level : float
var xp_since_level : float



########################## 
##Levelling Calculations##
########################## 

# right now everything here is pipework for later when we implement
# exp and levelling. pretty much anything will give you exp: doing
# tasks, chatting, minigames, playtime, etc

## adds an amount of exp to the player, performing the exp calculation
## before returning the new exp value and executing the proper
## stuff if this will cause the player to levelup
func add_exp(amount : float):
	pass

## level the player up
func level_up():
	pass

## private function for properly adding EXP to increasingly higher
## levels, and returning the calcualted value
func _calculate_exp() -> float:
	return 0.0
	pass
