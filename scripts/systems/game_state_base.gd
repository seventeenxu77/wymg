@tool
class_name GameStateBase
extends Node2D

# Native Godot migration of the original web prototype.

const WORLD_25D_SCRIPT := preload("res://scripts/world_25d.gd")
const MAP_SIZE := 6
const ROOM_SIZE := 5.0
const ACTOR_SPEED := 4.0
const ACTOR_COLLISION_RADIUS := 0.25
const MONSTER_COLLISION_RADIUS := 576.0 * 0.00263 * 0.5 / WORLD_25D_SCRIPT.CELL_SIZE
const THIEF_COLLISION_RADIUS := 384.0 * 0.00270 * 0.5 / WORLD_25D_SCRIPT.CELL_SIZE
const FURNITURE_SPEED := 2.0
const ROTATION_SPEED := 90.0
const ROTATION_STEP := 4.0
const FURNITURE_HIT_REACH := 1.35
const FURNITURE_HIT_DOT := 0.62
const TRINKET_SPAWN_CHANCE := 0.5
const PILL_SPAWN_COUNT := 3
const HIDDEN_ADRENALINE_COUNT := 4
const HIT_WINDUP_TIME := 0.16
const HIT_LUNGE_TIME := 0.14
const HIT_RECOVER_TIME := 0.16
const HIT_WINDUP_DISTANCE := 0.22
const HIT_LUNGE_DISTANCE := 0.38
const MONSTER_ATTACK_COOLDOWN := 10.0
const MONSTER_ATTACK_ANIMATION_SECONDS := 0.55
const MONSTER_ATTACK_HIT_STUN_SECONDS := 0.8
const AFTERIMAGE_LINGER_SECONDS := 1.1 * 1.25
const VOICE_COOLDOWN_SECONDS := 1.0
const VOICE_NOISE_SECONDS := 3.0
const TOOL_INVENTORY_CAPACITY := 3
const DETECTOR_BATTERY_SECONDS := 54.0
const DETECTOR_NOISE_INTERVAL := 3.0
const TRAP_ESCAPE_PRESSES := 20
const TRAP_TRIGGER_RADIUS := 0.34
const TRAP_ARM_DELAY := 0.6
const ADRENALINE_SECONDS := 6.0
const FATIGUE_SECONDS := 3.0
const DECOY_SECONDS := 10.0
const DECOY_SPEED := ACTOR_SPEED
const DECOY_DASH_DISTANCE := 1.15
const PHONOGRAPH_DELAY := 2.0
const PHONOGRAPH_SECONDS := 10.0
const TELEPORT_CHANNEL_SECONDS := 5.0
const SPRING_GLOVE_REACH := 1.45
const SPRING_GLOVE_KNOCKBACK := 1.2
const SPRING_GLOVE_STUN_SECONDS := 1.0
const ROBOT_SPEED := ACTOR_SPEED * 0.5
const ROBOT_ROOM_WANDER_POINTS := 3
const ROBOT_STUN_SECONDS := 10.0
const ROBOT_ALARM_SECONDS := 3.0
const ROBOT_ALARM_COOLDOWN := 8.0
const TOOL_INSPECT_DISTANCE := 1.05
const PICKUP_DISTANCE := 0.64
const THIEF_HIDE_DELAY := 0.0
const THIEF_REVEAL_SECONDS := 1.0
const NOISE_SAMPLE_RATE := 11025
const MATCH_ROUNDS := 4
const HUNT_SECONDS := 8 * 60
const COINS_PER_LOOT_VALUE := 1
const ENTRANCE_ROOM := Vector2i(0, 5)
const ENTRANCE_POS := Vector2(0.5, 4.5)
const MONSTER_SPAWN_ROOM := Vector2i(5, 0)
const MONSTER_SPAWN_POS := Vector2(4.5, 0.5)

const MONSTER_COLOR := Color("#ff6b4a")
const THIEF_COLOR := Color("#66d9c3")
const BG_COLOR := Color("#0b0c0c")
const PANEL_COLOR := Color("#171a17")
const PANEL_ALT := Color("#111312")
const LINE_COLOR := Color("#3d413b")
const TEXT_COLOR := Color("#eee9dd")
const MUTED_COLOR := Color("#979c94")
const FLOOR_COLOR := Color("#70756b")
const FLOOR_DARK := Color("#63685f")
const GOLD_COLOR := Color("#e6cc64")
const TRACE_COLOR := Color("#d5c78f")

const DIRECTIONS := [
	{"name": "up", "delta": Vector2i(0, -1), "opposite": "down"},
	{"name": "right", "delta": Vector2i(1, 0), "opposite": "left"},
	{"name": "down", "delta": Vector2i(0, 1), "opposite": "up"},
	{"name": "left", "delta": Vector2i(-1, 0), "opposite": "right"},
]

const TREASURES := [
	{
		"id": "treasure-2",
		"kind": "treasure",
		"label": "银制烛台",
		"value": 4,
		"description": "沾着凝固烛泪的旧银烛台，仍映着宅邸过去的微光。",
	},
	{
		"id": "treasure-3",
		"kind": "treasure",
		"label": "祖母绿胸针",
		"value": 6,
		"description": "镶嵌祖母绿的古老胸针，宝石深处浮动着幽绿色泽。",
	},
	{
		"id": "treasure-5",
		"kind": "treasure",
		"label": "怪物之心",
		"value": 10,
		"description": "离开身体后仍在搏动的异形心脏，是宅邸中最危险的珍藏。",
	},
]

const TRINKETS := ["旧怀表", "银汤匙", "铜制烟盒", "珍珠纽扣"]
const WILD_TREASURE_COUNT := 10
const WILD_TREASURE := {"id": "treasure-1", "kind": "treasure", "label": "古钱币", "value": 2}

const TOOL_DEFS := {
	"detector": {
		"label": "藏品探测器",
		"short": "探测",
		"description": "开启后探测同一房间内的藏品信号；总电量54秒，可随时关闭以保留电量。",
		"color": Color("#78d7e8"),
		"price": 5,
	},
	"alarm": {
		"label": "警报器",
		"short": "警报",
		"description": "藏进完好家具；家具被撞开后全图鸣响5秒。",
		"color": Color("#f0735f"),
		"price": 2,
	},
	"trap": {
		"label": "捕兽夹",
		"short": "兽夹",
		"description": "放置在地面，踩中者需左右交替20次才能挣脱。",
		"color": Color("#c6a66a"),
		"price": 3,
	},
	"adrenaline": {
		"label": "肾上腺素",
		"short": "加速",
		"description": "速度翻倍6秒，随后进入3秒减速疲劳。",
		"color": Color("#e45b68"),
		"price": 2,
	},
	"decoy": {
		"label": "替身玩偶",
		"short": "替身",
		"description": "本体向前位移，替身沿反方向奔跑10秒。",
		"color": Color("#b98be2"),
		"price": 3,
	},
	"phonograph": {
		"label": "留声机",
		"short": "留声",
		"description": "放置后再次靠近启动，延迟播放10秒撞击声。",
		"color": Color("#d49a5b"),
		"price": 3,
	},
	"teleporter": {
		"label": "传送器",
		"short": "传送",
		"description": "仅盗贼可用；轰鸣5秒后携带全部藏品撤离。",
		"color": Color("#68c8ff"),
		"price": 8,
	},
	"spring_glove": {
		"label": "弹簧拳套",
		"short": "拳套",
		"description": "击退相邻敌人并使其眩晕1秒，一次性使用。",
		"color": Color("#f1c65a"),
		"price": 4,
	},
	"robot": {
		"label": "发条巡夜偶",
		"short": "巡夜偶",
		"description": "以半速在召唤点九宫格内巡逻；巡查房间后才会换房，发现敌人后报警。",
		"color": Color("#8fd0a4"),
		"price": 5,
	},
}

const SHOP_TOOL_TYPES := [
	"adrenaline",
	"alarm",
	"trap",
	"decoy",
	"phonograph",
	"spring_glove",
	"detector",
	"teleporter",
	"robot",
]

const SOUND_PATHS := {
	"walk": "res://GJGamejam素材/music/walksound.mp3",
	"furniture_hit": "res://GJGamejam素材/music/woodsmashsound.mp3",
	"furniture_open": "res://GJGamejam素材/music/openboxsound.mp3",
	"attack": "res://GJGamejam素材/music/swordslashsound.mp3",
	"scream": "res://GJGamejam素材/music/malehorrorscream.mp3",
	"laugh": "res://GJGamejam素材/music/witchlaugh.mp3",
	"monster_win": "res://GJGamejam素材/music/witchlaugh.mp3",
}

var rng := RandomNumberGenerator.new()
var rooms: Array = []
var monster: Dictionary = {}
var thief: Dictionary = {}
var dragging := {"monster": "", "thief": ""}
var drag_mode := {"monster": "move", "thief": "move"}
var furniture_hit_actions := {"monster": {}, "thief": {}}
var active_storage_id := ""
var selected_treasure := 0
var loot_value := 0
var stolen_monster_value := 0
var extracted_value := 0
var has_extracted := false
var pills := 0
var phase := "hide"
var seconds_left := 180
var phase_clock := 0.0
var elapsed := 0.0
var stomach_clock := 15.0
var attack_until := 0.0
var noises: Array = []
var afterimages: Array = []
var last_afterimage_at := -10.0
var outcome := ""
var logs: Array[String] = []
var restart_rect := Rect2()
var early_rect := Rect2()
var result_restart_rect := Rect2()
var match_end_selected := 0
var match_end_rects: Dictionary = {}
var help_open := {"monster": false, "thief": false}
var help_rects := {"monster": Rect2(), "thief": Rect2()}
var tool_inventories := {"monster": [], "thief": []}
var tool_selected := {"monster": 0, "thief": 0}
var status_effects := {"monster": {}, "thief": {}}
var trapped_by := {"monster": "", "thief": ""}
var trap_escape_progress := {"monster": 0, "thief": 0}
var trap_expected_left := {"monster": true, "thief": true}
var next_device_id := 0
var current_round := 1
var player_coins := {"A": 0, "B": 0}
var player_stashes := {"A": [], "B": []}
var player_loadouts := {"A": [], "B": []}
var shop_selected := {"A": 0, "B": 0}
var shop_focus := {"A": "products", "B": "products"}
var warehouse_selected := {"A": 0, "B": 0}
var loadout_selected := {"A": 0, "B": 0}
var shop_ready := {"A": false, "B": false}
var round_awards := {"A": 0, "B": 0}
var match_totals := {"A": 0, "B": 0}
var sound_streams: Dictionary = {}
var sound_last_played: Dictionary = {}
var walk_players: Dictionary = {}
var sound_players: Dictionary = {}
var gm_console_open := false
var gm_command := ""
var gm_output := "输入 help 查看命令。"
var gm_history: Array[String] = []
var main_menu_open := false
var main_menu_panel := "root"
var main_menu_selected := 0
var main_menu_volume_step := 8
var main_menu_rects: Dictionary = {}
var game_pause_open := false
var game_pause_selected := 0
var game_pause_rects: Dictionary = {}
var tutorial_transition_active := false

var font: Font
var world_25d: World25D


func new_game() -> void:
	pass


func _start_round() -> void:
	pass
