extends Control

const CraftingDB = preload("res://Scripts/crafting recipes.gd")

# روابط العقد
@onready var recipe_list_container: GridContainer = $PanelContainer/HBoxContainer/ScrollContainer/RecipeListContainer
@onready var item_name_label: Label = $PanelContainer/HBoxContainer/VBoxContainer/ItemNameLabel
@onready var ingredients_container: Control = $PanelContainer/HBoxContainer/VBoxContainer/IngredientsContainer
@onready var craft_button: TextureButton = $PanelContainer/HBoxContainer/VBoxContainer/HBoxContainer/CraftButton
@onready var result_slot: Control = $PanelContainer/HBoxContainer/VBoxContainer/HBoxContainer/ResultSlot

# متغيرات
var player_node
var current_selected_recipe: String = ""
var crafting_slots: Array = []
var current_drag_recipe: String = ""
var last_match_cells: Array = [] # indices (0..8) of slots used for shaped match
var last_match_shaped: bool = false

func _ready():
	# إخفاء الواجهة عند البداية
	hide()
	# ضبط نص زر التصنيع ليكون قابلًا للترجمة
	var craft_label: Label = $PanelContainer/HBoxContainer/VBoxContainer/HBoxContainer/CraftButton/Carft
	if is_instance_valid(craft_label):
		craft_label.text = tr("CRAFT")

# دالة لفتح الواجهة وتحديثها
func open_ui(player):
	player_node = player
	_setup_crafting_slots()
	populate_recipe_list()
	_recalculate_result()
	# وصل إشارة فتحة الناتج
	if result_slot and result_slot.has_signal("craft_requested") and result_slot.is_connected("craft_requested", Callable(self, "_on_result_craft_requested")) == false:
		result_slot.connect("craft_requested", Callable(self, "_on_result_craft_requested"))
	show()

# إنشاء وربط فتحات السحب الخاصة بالتصنيع
func _setup_crafting_slots():
	crafting_slots.clear()
	# Ensure consistent order Slot1..Slot9 (row-major)
	for i in range(1, 10):
		var name = "Slot" + str(i)
		var child = ingredients_container.get_node_or_null(name)
		if child and child.has_method("set_context"):
			child.set_context(player_node)
			if child.has_signal("changed") and not child.is_connected("changed", Callable(self, "_on_slots_changed")):
				child.connect("changed", Callable(self, "_on_slots_changed"))
			crafting_slots.append(child)

func _on_slots_changed():
	_recalculate_result()

# دالة لملء قائمة الوصفات (اختياري)
func populate_recipe_list():
	# مسح القائمة القديمة
	for child in recipe_list_container.get_children():
		child.queue_free()
		
	# إضافة زر لكل وصفة في قاعدة البيانات
	for recipe_name in CraftingDB.RECIPES.keys():
		var button = Button.new()
		button.text = recipe_name.capitalize()
		# وصل الإشارة مع تمرير اسم الوصفة كـ bind
		button.connect("pressed", Callable(self, "select_recipe").bind(recipe_name))
		recipe_list_container.add_child(button)

# دالة لعرض تفاصيل الوصفة المختارة (قائمة الوصفات)
func select_recipe(recipe_name: String):
	current_selected_recipe = recipe_name
	var recipe_data = CraftingDB.RECIPES[recipe_name]
	item_name_label.text = tr("Crafting: ") + recipe_name.capitalize()
	# لا نغيّر فتحات السحب هنا

# Grid helpers
func _grid_snapshot_names() -> Array:
	# returns 3x3 array of names ("" for empty) in Slot1..Slot9 order
	var names: Array = []
	for i in range(crafting_slots.size()):
		var s = crafting_slots[i]
		var n := ""
		if s and s.has_method("get_item_name"):
			n = String(s.get_item_name())
		names.append(n)
	return [names.slice(0, 3), names.slice(3, 6), names.slice(6, 9)]

func _grid_snapshot_counts() -> Array:
	var counts: Array = []
	for i in range(crafting_slots.size()):
		var s = crafting_slots[i]
		var c := 0
		if s and s.has_method("get_quantity"):
			c = int(s.get_quantity())
		counts.append(c)
	return [counts.slice(0, 3), counts.slice(3, 6), counts.slice(6, 9)]

# حساب العناصر داخل فتحات السحب (shapeless summary)
func _collect_slot_counts() -> Dictionary:
	var counts := {}
	for slot in crafting_slots:
		var name: String = ""
		if slot.has_method("get_item_name"):
			name = String(slot.get_item_name())
		var qty: int = 0
		if slot.has_method("get_quantity"):
			qty = int(slot.get_quantity())
		if name != "" and qty > 0:
			counts[name] = counts.get(name, 0) + qty
	return counts

func _find_matching_recipe(counts: Dictionary) -> String:
	# Try shaped recipes first
	var grid_names = _grid_snapshot_names()
	var grid_counts = _grid_snapshot_counts()
	for recipe_name in CraftingDB.RECIPES.keys():
		var r = CraftingDB.RECIPES[recipe_name]
		if r.has("shaped") and r["shaped"]:
			var match = _try_match_shaped(r, grid_names)
			if match.size() > 0:
				last_match_cells = match
				last_match_shaped = true
				return recipe_name
	# Fall back to shapeless
	last_match_shaped = false
	last_match_cells = []
	for recipe_name in CraftingDB.RECIPES.keys():
		var r2 = CraftingDB.RECIPES[recipe_name]
		if not (r2.has("shaped") and r2["shaped"]):
			var ings: Dictionary = r2.ingredients
			if counts.keys().size() != ings.keys().size():
				continue
			var all_match := true
			for ing_name in ings.keys():
				if counts.get(ing_name, -1) != int(ings[ing_name]):
					all_match = false
					break
			if all_match:
				return recipe_name
	return ""

# shaped matching: slide pattern over 3x3 and ensure outside pattern empty
func _try_match_shaped(r: Dictionary, grid_names: Array) -> Array:
	if not (r.has("pattern") and r.has("key")):
		return []
	var pattern: Array = r["pattern"]
	var keymap: Dictionary = r["key"]
	var ph := pattern.size()
	# عرض النمط = أقصى طول among الصفوف
	var pw: int = 0
	if ph > 0:
		for py in range(ph):
			if pattern[py] is String:
				pw = max(pw, pattern[py].length())
	if pw <= 0:
		return []
	for oy in range(0, 3 - ph + 1):
		for ox in range(0, 3 - pw + 1):
			var used_cells: Array = []
			var ok := true
			# check pattern area
			for py in range(ph):
				var row = pattern[py]
				if not (row is String):
					ok = false
					break
				for px in range(pw):
					# السماح بصفوف أقصر: يعامل كفراغ بعد نهاية الصف
					var sym: String = " " if px >= row.length() else str(row[px])
					var name_here = grid_names[oy + py][ox + px]
					if sym == " ":
						if name_here != "": ok = false; break
					else:
						var req = String(keymap.get(String(sym), ""))
						if req == "" or name_here != req:
							ok = false; break
						used_cells.append((oy + py) * 3 + (ox + px))
				if not ok: break
			if not ok: continue
			# ensure cells outside pattern are empty
			for gy in range(3):
				for gx in range(3):
					if gy >= oy and gy < oy + ph and gx >= ox and gx < ox + pw:
						continue
					if grid_names[gy][gx] != "":
						ok = false; break
				if not ok: break
			if ok:
				return used_cells
	return []

func _recalculate_result():
	var counts := _collect_slot_counts()
	var match := _find_matching_recipe(counts)
	current_drag_recipe = match
	if match == "":
		item_name_label.text = tr("No matching recipe")
		if craft_button:
			craft_button.disabled = true
		if result_slot and result_slot.has_method("clear"):
			result_slot.clear()
	else:
		var q := int(CraftingDB.RECIPES[match].output_quantity)
		item_name_label.text = tr("Can craft: %s x%d") % [match.capitalize(), q]
		if craft_button:
			craft_button.disabled = false
		if result_slot and result_slot.has_method("set_item"):
			result_slot.set_item(player_node, match, q)

# دالة تنفيذ التصنيع (تستعمل إما نتيجة السحب أو الوصفة المحددة)
func on_craft_button_pressed():
	if not player_node:
		return
	var recipe_name := current_drag_recipe
	if recipe_name == "":
		# fallback للوصفة المختارة من القائمة
		recipe_name = current_selected_recipe
	if recipe_name == "":
		return
	var recipe_data: Dictionary = CraftingDB.RECIPES[recipe_name]
	var is_shaped: bool = recipe_data.has("shaped") and recipe_data["shaped"]
	if is_shaped:
		# shaped recipes must be crafted from the grid when a shaped match exists
		if recipe_name != current_drag_recipe or not last_match_shaped:
			return
		_consume_shaped_once()
	else:
		# shapeless: craft from grid if dragging, otherwise from inventory ingredients
		if recipe_name == current_drag_recipe:
			if recipe_data.has("ingredients"):
				_consume_from_slots(recipe_data["ingredients"])
			else:
				return
		else:
			if not recipe_data.has("ingredients"):
				return
			for ing in recipe_data["ingredients"].keys():
				player_node.remove_item(ing, int(recipe_data["ingredients"][ing]))
	# أضف الناتج
	if recipe_data.has("output_quantity"):
		player_node.add_item(recipe_name, int(recipe_data["output_quantity"]))
	else:
		player_node.add_item(recipe_name, 1)
	_recalculate_result()

func _on_result_craft_requested(amount: int) -> void:
	if current_drag_recipe == "" or not player_node:
		return
	var times := 1
	if last_match_shaped:
		if amount < 0:
			times = _compute_max_crafts_shaped()
		if times <= 0:
			return
		for i in range(times):
			_consume_shaped_once()
			player_node.add_item(current_drag_recipe, int(CraftingDB.RECIPES[current_drag_recipe].output_quantity))
	else:
		var ing: Dictionary = CraftingDB.RECIPES[current_drag_recipe].ingredients
		if amount < 0:
			times = _compute_max_crafts_from_slots(ing)
		if times <= 0:
			return
		for i in range(times):
			_consume_from_slots(ing)
			player_node.add_item(current_drag_recipe, int(CraftingDB.RECIPES[current_drag_recipe].output_quantity))
	_recalculate_result()

func _compute_max_crafts_from_slots(ingredients: Dictionary) -> int:
	var counts := _collect_slot_counts()
	var max_times := 999999
	for name in ingredients.keys():
		var need := int(ingredients[name])
		var have := int(counts.get(name, 0))
		if have <= 0:
			return 0
		max_times = min(max_times, int(have / need))
	return max(0, int(max_times))

func _compute_max_crafts_shaped() -> int:
	# based on last_match_cells, each cell contributes its quantity; min across used cells
	var min_qty := 999999
	for idx in last_match_cells:
		var s = crafting_slots[int(idx)]
		if s and s.has_method("get_quantity"):
			min_qty = min(min_qty, int(s.get_quantity()))
		else:
			return 0
	return max(0, min_qty)

func _consume_from_slots(ingredients: Dictionary) -> void:
	for ing_name in ingredients.keys():
		var need := int(ingredients[ing_name])
		for slot in crafting_slots:
			if need <= 0:
				break
			if slot.has_method("get_item_name") and String(slot.get_item_name()) == ing_name:
				if slot.has_method("remove_amount"):
					var removed: int = int(slot.remove_amount(need))
					need -= removed
	_on_slots_changed()

func _consume_shaped_once() -> void:
	# remove one from each used cell
	for idx in last_match_cells:
		var s = crafting_slots[int(idx)]
		if s and s.has_method("remove_one"):
			s.remove_one()
	_on_slots_changed()
