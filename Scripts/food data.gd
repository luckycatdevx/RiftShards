extends Node
# قاعدة بيانات لخصائص الأطعمة.

# القاموس الرئيسي الذي يحتوي على بيانات الطعام
# الصيغة: "اسم_الطعام": { "hunger_restored": X }
const DATA = {
	"apple": {
		"hunger_restored": 2
	},
	"bread": {
		"hunger_restored": 4
	},
	"meat": {
		"hunger_restored": 4
	},
	"cooked_meat": {
		"hunger_restored": 6
	}
	# ... أضف المزيد من الأطعمة هنا
}

# دالة للتحقق مما إذا كان عنصر ما طعامًا
static func is_food(item_name: String) -> bool:
	return DATA.has(item_name)

# دالة للحصول على قيمة استعادة الجوع
static func get_hunger_value(item_name: String) -> int:
	if is_food(item_name):
		return DATA[item_name].hunger_restored
	return 0
