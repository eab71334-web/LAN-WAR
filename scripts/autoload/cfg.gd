extends Node
## الإعدادات الثابتة للعبة (من وثيقة المواصفات)

const GAME_NAME := "LAN WAR"
const PORT := 24680
const DISCOVERY_PORT := 24681
const MAX_PLAYERS := 16
const MAX_PER_TEAM := 4

const TEAMS := [
	{"name": "الفريق الأحمر", "color": Color(0.86, 0.16, 0.16)},
	{"name": "الفريق الأزرق", "color": Color(0.16, 0.38, 0.88)},
	{"name": "الفريق الأخضر", "color": Color(0.18, 0.70, 0.25)},
	{"name": "الفريق الأصفر", "color": Color(0.95, 0.80, 0.12)},
]

# حدود المركبات الإجمالية للمباراة (وليست لكل فريق) = 52
const LIMIT_DEFAULTS := {"mlrs": 8, "heli": 8, "tank": 12, "light": 8, "jet": 16}
const LIMIT_NAMES := {
	"mlrs": "راجمات M270 MLRS", "heli": "مروحيات", "tank": "دبابات",
	"light": "جيبات وناقلات جنود", "jet": "طائرات مقاتلة",
}

const MAPS := {
	"ruined_city": "مدينة مدمرة", "desert_base": "صحراء عسكرية",
	"forest": "غابة", "military_base": "قاعدة عسكرية",
}

const CLASSES := {
	"assault": {"name": "جندي اقتحام", "hp": 120.0, "speed": 6.0},
	"sniper": {"name": "قناص", "hp": 80.0, "speed": 6.0},
	"engineer": {"name": "مهندس عسكري", "hp": 100.0, "speed": 6.0},
	"medic": {"name": "مسعف", "hp": 100.0, "speed": 6.5},
}

const WEAPONS := {
	"rifle": {"name": "بندقية هجومية", "dmg": 22.0, "rate": 0.11, "range": 250.0},
	"sniper": {"name": "بندقية قناصة", "dmg": 95.0, "rate": 1.3, "range": 600.0},
	"lmg": {"name": "رشاش", "dmg": 17.0, "rate": 0.075, "range": 200.0},
	"support": {"name": "سلاح دعم", "dmg": 34.0, "rate": 0.25, "range": 220.0},
}

# مكان الانتشار. cat = فئة حد المركبات ("" = جندي بلا مركبة)
const KINDS := {
	"soldier": {"name": "جندي على الأرض", "cat": ""},
	"jeep": {"name": "جيبة عسكرية", "cat": "light"},
	"apc": {"name": "ناقلة جنود", "cat": "light"},
	"tank": {"name": "دبابة", "cat": "tank"},
	"mlrs": {"name": "راجمة M270 MLRS", "cat": "mlrs"},
	"heli": {"name": "مروحية", "cat": "heli"},
	"jet": {"name": "طائرة مقاتلة", "cat": "jet"},
}

const VSTATS := {
	"jeep": {"mode": "wheel", "speed": 24.0, "accel": 14.0, "turn": 1.5, "hp": 350.0, "armor": 0.5, "size": Vector3(2.2, 1.6, 4.4), "weapon": "gun", "dmg": 14.0, "rate": 0.1, "ammo": -1, "cam": 9.0},
	"apc": {"mode": "wheel", "speed": 16.0, "accel": 8.0, "turn": 1.1, "hp": 700.0, "armor": 0.2, "size": Vector3(2.9, 2.0, 6.0), "weapon": "gun", "dmg": 20.0, "rate": 0.1, "ammo": -1, "cam": 11.0},
	"tank": {"mode": "track", "speed": 11.0, "accel": 5.0, "turn": 0.9, "hp": 1400.0, "armor": 0.06, "size": Vector3(3.4, 1.9, 7.2), "weapon": "cannon", "dmg": 150.0, "rate": 2.2, "ammo": -1, "cam": 14.0, "radius": 5.0},
	"mlrs": {"mode": "track", "speed": 9.0, "accel": 4.0, "turn": 0.7, "hp": 900.0, "armor": 0.1, "size": Vector3(3.2, 2.4, 7.0), "weapon": "rocket", "dmg": 230.0, "rate": 2.5, "ammo": 12, "cam": 15.0, "radius": 10.0},
	"heli": {"mode": "heli", "speed": 32.0, "accel": 10.0, "turn": 1.5, "hp": 800.0, "armor": 0.15, "size": Vector3(2.6, 3.0, 9.0), "weapon": "gun", "dmg": 22.0, "rate": 0.08, "ammo": -1, "cam": 16.0, "climb": 12.0},
	"jet": {"mode": "jet", "speed": 95.0, "min": 38.0, "hp": 600.0, "armor": 0.15, "size": Vector3(8.0, 2.0, 12.0), "weapon": "gun", "dmg": 30.0, "rate": 0.06, "ammo": -1, "cam": 20.0},
}


var is_mobile := false
var touch_live := false   # true أثناء اللعب الفعلي (ليس أثناء شاشة التجهيز)


func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")
	_setup_input()


## هل المدخلات (ماوس ملتقط أو لمس) فعّالة الآن؟
func input_live() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (is_mobile and touch_live)


func default_settings() -> Dictionary:
	return {
		"max_players": MAX_PLAYERS, "team_count": 4, "team_choice": false,
		"bots": false, "map": "", "win_score": 30, "respawn": 5.0,
		"damage": 1.0, "limits": LIMIT_DEFAULTS.duplicate(), "locked": false,
	}


func _setup_input() -> void:
	var keys := {
		"move_fwd": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "interact": KEY_E,
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[a] as Key
		InputMap.action_add_event(a, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	if not is_mobile:   # على الجوال اللمس يُحاكي الماوس، فلا نربط الإطلاق به
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)
