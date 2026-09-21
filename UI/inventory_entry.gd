extends Button

var item: Item

func setup(new_item: Item, amount: int):
	item = new_item
	text = item.item_name + " x" + str(amount)
