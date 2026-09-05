# Authored by Max Royer

class_name ChatMessageUI
extends RichTextLabel

func create_message(
	messenger_name : String, 
	messenger_name_color : Color,
	messenger_message : String,
	messenger_message_color := Color.WHITE
) -> void:
	
	## hardcoded unique name/message color for admins
	if Debug.admin_list.has(messenger_name):
		messenger_name_color = Color.DEEP_PINK
		messenger_message_color = Color.DEEP_PINK
	
	## sanity check for the message
	
	self.text = ("[color=%s][%s][/color]: [color=%s]%s[/color]" % [messenger_name_color.to_html(), messenger_name, messenger_message_color.to_html(), messenger_message])
