class_name InventorySlot
extends Resource


var item: Item
var amount: int

func _init(new_item: Item = null, new_amount: int = 0):
	item = new_item
	amount = new_amount

func is_empty() -> bool:
	return item == null or amount <= 0
