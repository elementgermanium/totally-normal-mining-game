extends Button

var item: Item

func setup(recipe: CraftingRecipe):
	text = " "
	var output_parts: Array[String] = []
	for output in recipe.outputs:
		output_parts.append(
			output.item.item_name + " x" + str(output.amount)
		)
	text += ", ".join(output_parts)
	text += ": "
	var input_parts: Array[String] = []
	for input in recipe.inputs:
		input_parts.append(
			input.item.item_name + " x" + str(input.amount)
		)
	text += ", ".join(input_parts)
