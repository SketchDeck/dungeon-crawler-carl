class_name Config
extends RefCounted
## Central balance and tuning values. Everything that is meant to be tuned lives here.

# --- Player movement ---------------------------------------------------------
const MOVE_SPEED := 230.0
const ACCEL_GROUND := 2600.0
const FRICTION_GROUND := 2400.0
const ACCEL_AIR := 1300.0
const JUMP_VELOCITY := -530.0
const JUMP_CUT_MULTIPLIER := 0.45
const MAX_FALL_SPEED := 900.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1
const DASH_SPEED := 640.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 0.8
const DASH_INVULN := 0.15

# --- Player health / potions / lives -----------------------------------------
const PLAYER_MAX_HP := 100
const PLAYER_HIT_INVULN := 0.75
const LIVES := 3
const FLOOR_COUNT := 2
const POTION_HEAL := 30
const POTION_CAPACITY := 10
const POTION_START := 3
const POTION_USE_COOLDOWN := 0.5
const POTION_DROP_CHANCE := 0.2

# --- Regeneration / combat state ---------------------------------------------
const REGEN_DELAY := 3.0
const REGEN_DURATION := 10.0
const ENEMY_DISENGAGE_TIME := 4.0

# --- Carl (physical) ---------------------------------------------------------
const KICK_DAMAGE := [10, 10, 20]
const KICK_KNOCKBACK := [170.0, 190.0, 420.0]
const KICK_DURATION := 0.22
const KICK_RECOVERY := 0.12
const KICK_COMBO_WINDOW := 0.55
const KICK_RANGE := 46.0
const CHARGE_KICK_MIN_DAMAGE := 15
const CHARGE_KICK_MAX_DAMAGE := 35
const CHARGE_KICK_MIN_KNOCKBACK := 300.0
const CHARGE_KICK_MAX_KNOCKBACK := 680.0
const CHARGE_TIME := 1.1
const CHARGE_KICK_COOLDOWN := 0.7
const EXPLOSIVE_KICK_COOLDOWN := 3.0
const EXPLOSIVE_KICK_DAMAGE := 24
const EXPLOSIVE_KICK_RADIUS := 120.0
const EXPLOSIVE_KICK_KNOCKBACK := 520.0

# --- Donut (magical) ---------------------------------------------------------
const MAGIC_DAMAGE := 12
const MAGIC_COOLDOWN := 0.35
const MAGIC_SPEED := 540.0
const MAGIC_RANGE := 430.0
const BLAST_MIN_DAMAGE := 18
const BLAST_MAX_DAMAGE := 35
const BLAST_COOLDOWN := 0.9
const BLAST_SPEED := 380.0
const BLAST_RANGE := 620.0
const AREA_BURST_COOLDOWN := 4.0
const AREA_BURST_RADIUS := 170.0
const AREA_BURST_DAMAGE := 20
const AREA_BURST_KNOCKBACK := 460.0

# --- Enemies -----------------------------------------------------------------
const GOBLIN_HP := 40
const GOBLIN_SPEED := 105.0
const GOBLIN_DETECT_RANGE := 300.0
const GOBLIN_ATTACK_RANGE := 46.0
const GOBLIN_DAMAGE := 12
const GOBLIN_ATTACK_COOLDOWN := 1.3
const GOBLIN_TELEGRAPH := 0.45
const SLIME_HP := 30
const SLIME_HOP_INTERVAL := 1.6
const SLIME_HOP_SPEED := 170.0
const SLIME_HOP_VELOCITY := -380.0
const SLIME_DAMAGE := 8
const SLIME_TELEGRAPH := 0.5
const ENEMY_KNOCKBACK_FRICTION := 1400.0
const ENEMY_COLLISION_MIN_SPEED := 260.0
const ENEMY_COLLISION_DAMAGE := 10

# --- Environment -------------------------------------------------------------
const SPIKE_DAMAGE := 14
const EXPLOSIVE_OBJECT_DAMAGE := 26
const EXPLOSIVE_OBJECT_RADIUS := 110.0
const BREAKABLE_HP := 2

# --- Bosses ------------------------------------------------------------------
const BRUTE_HP := 320
const BRUTE_CHARGE_DAMAGE := 18
const BRUTE_SLAM_DAMAGE := 16
const BRUTE_SWING_DAMAGE := 26
const MUTANT_HP := 360
const MUTANT_PROJECTILE_DAMAGE := 10
const MUTANT_SLAM_DAMAGE := 16

# --- Upgrades (temporary, reset per floor) -----------------------------------
const UPGRADE_KICK_DAMAGE := 0.25
const UPGRADE_MAGIC_DAMAGE := 0.25
const UPGRADE_KNOCKBACK := 0.3
const UPGRADE_COOLDOWN := 0.2
const UPGRADE_MAX_HP := 25
const UPGRADE_MOVE_SPEED := 0.15

# --- Dungeon AI achievements -------------------------------------------------
const ACH_KNOCKBACK_ROOMS := 3
const ACH_KNOCKBACK_MULT := 1.35
const ACH_ENV_DAMAGE_ROOMS := 2
const ACH_ENV_DAMAGE_MULT := 1.3
const ACH_ROOM_CLEAR_HEAL := 15

# --- Save file ---------------------------------------------------------------
const SAVE_PATH := "user://save_game.json"

# --- Physics layers (bit values) ---------------------------------------------
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_HAZARD := 8
const LAYER_PICKUP := 16
const LAYER_PROJECTILE := 32
const LAYER_DOOR := 64
