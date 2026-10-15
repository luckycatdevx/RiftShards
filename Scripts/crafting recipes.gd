extends Node
# القاموس الرئيسي الذي يحتوي على كل الوصفات

# الصيغة: "اسم_الناتج": { "كمية_الناتج": X, "المكونات": { "اسم_المكون_1": Y, "اسم_المكون_2": Z } }
const RECIPES = {
	"planks": {
		"output_quantity": 4,
		"shaped": true,
		"pattern": [
			"W"
		],
		"key": {"W": "wood"}
	},
	"stick": {
		"output_quantity": 8,
		"shaped": true,
		"pattern": [
			"P",
			"P"
		],
		"key": {"P": "planks"}
	},
	"working_table": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"PP",
			"PP"
		],
		"key": {"P": "planks"}
	},
	"torch": {
		"output_quantity": 2,
		"shaped": true,
		"pattern": [
			"C",
			"S"
		],
		"key": {"S": "stick", "C": "coal"}
	},
	"wood_pickaxe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"PPP",
			"PSP",
			" S "
		],
		"key": {"P": "planks", "S": "stick"}
	},
	"wood_axe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"PP",
			"PS",
			" S "
		],
		"key": {"P": "planks", "S": "stick"}
	},
	"wood_shovel": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"P",
			"S",
			"S"
		],
		"key": {"P": "planks", "S": "stick"}
	},
	"wood_sword": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			" P ",
			"PPP",
			" S "
		],
		"key": {"P": "planks", "S": "stick"}
	},
	"stone_pickaxe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"TTT",
			"TST",
			" S "
		],
		"key": {"T": "stone", "S": "stick"}
	},
	"stone_axe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"TT",
			"TS",
			" S "
		],
		"key": {"T": "stone", "S": "stick"}
	},
	"stone_shovel": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"T",
			"S",
			"S"
		],
		"key": {"T": "stone", "S": "stick"}
	},
	"stone_sword": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			" T ",
			"TTT",
			" S "
		],
		"key": {"T": "stone", "S": "stick"}
	},
	"iron_pickaxe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"III",
			"ISI",
			" S "
		],
		"key": {"I": "iron", "S": "stick"}
	},
	"iron_axe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"II",
			"IS",
			" S "
		],
		"key": {"I": "iron", "S": "stick"}
	},
	"iron_shovel": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"I",
			"S",
			"S"
		],
		"key": {"I": "iron", "S": "stick"}
	},
	"iron_sword": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			" I ",
			"III",
			" S "
		],
		"key": {"I": "iron", "S": "stick"}
	},
	"gold_pickaxe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"GGG",
			"GSG",
			" S "
		],
		"key": {"G": "gold", "S": "stick"}
	},
	"gold_axe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"GG",
			"GS",
			" S "
		],
		"key": {"G": "gold", "S": "stick"}
	},
	"gold_shovel": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"G",
			"S",
			"S"
		],
		"key": {"G": "gold", "S": "stick"}
	},
	"gold_sword": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			" G ",
			"GGG",
			" S "
		],
		"key": {"G": "gold", "S": "stick"}
	},
	"diamond_pickaxe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"DDD",
			"DSD",
			" S "
		],
		"key": {"D": "diamond", "S": "stick"}
	},
	"diamond_axe": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"DD",
			"DS",
			" S "
		],
		"key": {"D": "diamond", "S": "stick"}
	},
	"diamond_shovel": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			"D",
			"S",
			"S"
		],
		"key": {"D": "diamond", "S": "stick"}
	},
	"diamond_sword": {
		"output_quantity": 1,
		"shaped": true,
		"pattern": [
			" D ",
			"DDD",
			" S "
		],
		"key": {"D": "diamond", "S": "stick"}
	},
	}
