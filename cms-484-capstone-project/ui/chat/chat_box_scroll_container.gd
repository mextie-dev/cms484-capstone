# Authored by Max Royer

extends ScrollContainer

@onready var vbox: VBoxContainer = $ChatMessageContainer

func _ready() -> void:
	#vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	
	vbox.resized.connect(_scroll_to_bottom)
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	#print("order changed")
	var v_scroll: VScrollBar = get_v_scroll_bar()
	scroll_vertical = int(v_scroll.max_value)
