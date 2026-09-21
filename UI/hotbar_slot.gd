extends PanelContainer

@onready var label = $Label

func display_item(item: Item, amount: int):
	if item == null:
		label.text = " "
		return
	label.text = item.item_name + "\n" + str(amount)

func set_selected(selected: bool):
	if selected:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.6, 0.6, 0.6, 1.0)
# Called when the node enters the scene tree for the first time.
