extends Node

class_name Game

enum Tile_Kind {
	NOTHING,
	PLAYER,
	EXIT_CLOSED,
	EXIT_OPENED,
	FLOWER,
	FLOWER_BLOOMED,
	ROCK,
	ROOT,
	BIG_CRATE,
}

enum Ground_Kind {
	WATER,
	GROUND,
	WATER_WITH_CRATE
}

signal level_completed

var grid_kind: Array[Tile_Kind] = []
var grid_info: Array = []
var grid_ground: Array[Ground_Kind] = []

var flower_seeds := 0:
	get:
		return flower_seeds
	set(value):
		flower_seeds_label.text = str(value)
		flower_seeds = value

@onready var tile_map: TileMap = $TileMap
@onready var flower_seeds_label = $UI/FlowerSeed
@onready var text_edit: TextEdit = $LevelEditor/TextEdit

var WIDTH := 9
var HEIGHT := 10

var updating_world := false

var undo_state: Array = []

var level_complete := false 

# [Flower seeds, Level Text]
var current_level = [1, """\
XXXXEXXXX
.........
.........
.........
X.....X..
..C...FW.
F.....X..
.........
X........
....P...."""]

# Called when the node enters the scene tree for the first time.
func _ready():
	text_edit.text = current_level[1]

func load_level(level: Array):
	current_level = level
	level_complete = false
	updating_world = false
	grid_kind.clear()
	grid_info.clear()
	grid_ground.clear()
	undo_state.clear()
	flower_seeds = level[0]
	var text = level[1]
	text_edit.text = text
	for x in text:
		match x:
			".":
				grid_kind.push_back(Tile_Kind.NOTHING)
				grid_info.push_back(null)
				grid_ground.push_back(Ground_Kind.GROUND)
			"E":
				grid_kind.push_back(Tile_Kind.EXIT_CLOSED)
				grid_info.push_back(null)
				grid_ground.push_back(Ground_Kind.GROUND)
			"W":
				grid_kind.push_back(Tile_Kind.NOTHING)
				grid_info.push_back(null)
				grid_ground.push_back(Ground_Kind.WATER)
			"X":
				grid_kind.push_back(Tile_Kind.ROCK)
				grid_info.push_back(null)
				grid_ground.push_back(Ground_Kind.GROUND)
			"F":
				grid_kind.push_back(Tile_Kind.FLOWER)
				grid_info.push_back(null)
				grid_ground.push_back(Ground_Kind.GROUND)
			"P":
				grid_kind.push_back(Tile_Kind.PLAYER)
				grid_info.push_back(Vector2i.UP)
				grid_ground.push_back(Ground_Kind.GROUND)
			"C":
				grid_kind.push_back(Tile_Kind.BIG_CRATE)
				grid_info.push_back(null)
				grid_ground.push_back(Ground_Kind.GROUND)
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var index = x + y * WIDTH
			set_tile(Vector2i(x, y), grid_kind[index], grid_info[index])
			set_ground(Vector2i(x, y), grid_ground[index])
	
	update_world()

func player_pos() -> Vector2i:
	for i in grid_kind.size():
		if grid_kind[i] == Tile_Kind.PLAYER:
			return Vector2i(i % WIDTH, i / WIDTH)
	
	push_error("Player not found")
	return Vector2i.ZERO

func player_pushable(tile: Tile_Kind) -> bool:
	match tile:
		Tile_Kind.BIG_CRATE:
			return true
			
	return false
	
func exit_pos() -> Vector2i:
	for i in grid_kind.size():
		if grid_kind[i] == Tile_Kind.EXIT_CLOSED or grid_kind[i] == Tile_Kind.EXIT_OPENED:
			return Vector2i(i % WIDTH, i / WIDTH)
	
	push_error("Exit not found")
	return Vector2i.ZERO

func can_player_move(direction: Vector2i) -> bool:
	var next_pos := player_pos() + direction
	var next_tile := get_tile(next_pos)
	if player_pushable(next_tile):
		return can_player_push(next_pos, direction)
	
	if get_ground(next_pos) == Ground_Kind.WATER:
		return false
	
	return next_tile == Tile_Kind.NOTHING || next_tile == Tile_Kind.EXIT_OPENED


func can_player_push(pos: Vector2i, direction: Vector2i) -> bool:
	var next_pos := pos + direction
	var target_tile := get_tile(next_pos)
	if player_pushable(target_tile):
		return can_player_push(next_pos, direction)
	
	return target_tile == Tile_Kind.NOTHING

func can_place_flower(pos: Vector2i) -> bool:
	return get_tile(pos) == Tile_Kind.NOTHING
	
func can_root_grow(pos: Vector2i) -> bool:
	if get_tile(pos) != Tile_Kind.NOTHING:
		return false
		
	if get_ground(pos) != Ground_Kind.GROUND:
		return false
		
	return true
			
func push_tile(pos: Vector2i, direction: Vector2i):
	var next_pos := pos + direction
	var next_tile := get_tile(next_pos)
	if player_pushable(next_tile):
		push_tile(next_pos, direction)
	set_tile(next_pos, get_tile(pos))
	set_tile(pos, Tile_Kind.NOTHING)

func player_move(direction: Vector2i):
	var current_pos := player_pos()
	var next_pos := current_pos + direction
	var next_tile := get_tile(next_pos)
	var next_ground := get_ground(next_pos)
		
	if can_player_push(next_pos, direction):
		push_tile(next_pos, direction)
		
	if next_tile == Tile_Kind.EXIT_OPENED:
		level_complete = true
	
	set_tile(current_pos, Tile_Kind.NOTHING)
	set_tile(next_pos, Tile_Kind.PLAYER, direction)
	
func get_tile(position: Vector2i) -> Tile_Kind:
	if position.x < 0 or position.x >= WIDTH or position.y < 0 or position.y >= HEIGHT:
		return Tile_Kind.ROCK
	var index = position.x + position.y * WIDTH
	return grid_kind[index]
	
func get_ground(position: Vector2i) -> Ground_Kind:
	if position.x < 0 or position.x >= WIDTH or position.y < 0 or position.y >= HEIGHT:
		return Ground_Kind.GROUND
	var index = position.x + position.y * WIDTH
	return grid_ground[index]

func set_ground(position: Vector2i, tile: Ground_Kind):
	var index = position.x + position.y * WIDTH
	grid_ground[index] = tile
	match tile:
		Ground_Kind.WATER:
			tile_map.set_cell(0, position, 0, Vector2i(0, 1))
		Ground_Kind.WATER_WITH_CRATE:
			tile_map.set_cell(0, position, 0, Vector2i(2, 3))
		Ground_Kind.GROUND:
			tile_map.set_cell(0, position, 0, Vector2i(2, 1))

func set_tile(position: Vector2i, tile: Tile_Kind, info = null):
	var index = position.x + position.y * WIDTH
	grid_kind[index] = tile
	grid_info[index] = info
	match tile:
		Tile_Kind.NOTHING:
			tile_map.set_cell(1, position, -1)
		Tile_Kind.ROCK:
			tile_map.set_cell(1, position, 0, Vector2i(1, 1))
		Tile_Kind.EXIT_CLOSED:
			tile_map.set_cell(1, position, 0, Vector2i(3, 0))
		Tile_Kind.EXIT_OPENED:
			tile_map.set_cell(1, position, 0, Vector2i(4, 0))
		Tile_Kind.PLAYER:
			match info:
				Vector2i.LEFT:
					tile_map.set_cell(1, position, 0, Vector2i(2, 2))
				Vector2i.RIGHT:
					tile_map.set_cell(1, position, 0, Vector2i(1, 2))
				Vector2i.UP:
					tile_map.set_cell(1, position, 0, Vector2i(0, 3))
				Vector2i.DOWN:
					tile_map.set_cell(1, position, 0, Vector2i(0, 2))
		Tile_Kind.FLOWER:
			tile_map.set_cell(1, position, 0, Vector2i(0, 0))
		Tile_Kind.FLOWER_BLOOMED:
			tile_map.set_cell(1, position, 0, Vector2i(1, 0))
		Tile_Kind.ROOT:
			tile_map.set_cell(1, position, 0, Vector2i(2, 0))
		Tile_Kind.BIG_CRATE:
			tile_map.set_cell(1, position, 0, Vector2i(1, 3))

func _input(event):
	if updating_world || level_complete:
		return
	if event.is_action_pressed("skip_level"):
		level_completed.emit()
	if event.is_action_pressed("show_editor"):
		$LevelEditor.visible = !$LevelEditor.visible
	if event.is_action_pressed("place_flower"):
		place_flower()
	if event.is_action_pressed("move_up"):
		move(Vector2i.UP)
	if event.is_action_pressed("move_down"):
		move(Vector2i.DOWN)
	if event.is_action_pressed("move_left"):
		move(Vector2i.LEFT)
	if event.is_action_pressed("move_right"):
		move(Vector2i.RIGHT)
	if event.is_action_pressed("undo"):
		undo()
	if event.is_action_pressed("reset"):
		reset()

func update_world():
	updating_world = true
	while update_world_tiles():
		await get_tree().create_timer(.05).timeout
	updating_world = false
		
func update_world_tiles() -> bool:
	var update_again := false
	var play_root_grow := false
	# Use a copy of grid to not update things added onaaaaaadaww this tick
	var grid_kind_copy := grid_kind.duplicate()
	var grid_info_copy := grid_info.duplicate()
	for i in grid_kind_copy.size():
		var pos = Vector2i(i % WIDTH, i / WIDTH)
		match grid_kind_copy[i]:
			Tile_Kind.FLOWER:
				var next_to_water = has_water_for_flower(pos + Vector2i.UP) or \
									has_water_for_flower(pos + Vector2i.DOWN) or \
									has_water_for_flower(pos + Vector2i.LEFT) or \
									has_water_for_flower(pos + Vector2i.RIGHT)
				if next_to_water:
					set_tile(pos, Tile_Kind.FLOWER_BLOOMED)
					update_again = true
			Tile_Kind.FLOWER_BLOOMED:
				for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if can_root_grow(pos + direction):
						set_tile(pos + direction, Tile_Kind.ROOT, direction)
						update_again = true
			Tile_Kind.ROOT:
				var direction: Vector2i = grid_info_copy[i]
				if can_root_grow(pos + direction):
					set_tile(pos + direction, Tile_Kind.ROOT, direction)
					update_again = true
					play_root_grow = true
					
	if play_root_grow:
		$RootGrow.play()
	
	return update_again

func has_water_for_flower(pos: Vector2i) -> bool:
	var tile := get_tile(pos)
	if tile == Tile_Kind.ROOT:
		return true
		
	var ground := get_ground(pos)
	if ground == Ground_Kind.WATER:
		return true
			
	return false

func move(direction: Vector2i):
	if can_player_move(direction):
		undo_state.push_back([flower_seeds, grid_kind.duplicate(), grid_info.duplicate(), grid_ground.duplicate()])
		$Walk.play()
		player_move(direction)
		await update_world()
		check_open_gate()
		if level_complete:
			level_completed.emit()

func place_flower():
	if flower_seeds == 0:
		return
	
	var direction := Vector2i.UP
	for i in grid_kind.size():
		if grid_kind[i] == Tile_Kind.PLAYER:
			direction = grid_info[i]
	var flower_pos := player_pos() + direction
	if can_place_flower(flower_pos):
		undo_state.push_back([flower_seeds, grid_kind.duplicate(), grid_info.duplicate()])
		flower_seeds -= 1
		set_tile(flower_pos, Tile_Kind.FLOWER)
		await update_world()
		check_open_gate()

func check_open_gate():
	# If exit already open or won, do nothing
	if exit_opened() || level_complete:
		return
	
	var all_flowers_bloomed = true
	for x in grid_kind:
		if x == Tile_Kind.FLOWER:
			all_flowers_bloomed = false
	if flower_seeds == 0 and all_flowers_bloomed:
		$GateOpen.play()
		set_tile(exit_pos(), Tile_Kind.EXIT_OPENED)

func exit_opened():
	for x in grid_kind:
		if x == Tile_Kind.EXIT_OPENED:
			return true
	return false

func undo():
	if len(undo_state) > 0:
		var old_state = undo_state.pop_back()
		flower_seeds = old_state[0]
		var state_kind = old_state[1]
		var state_info = old_state[2]
		var state_ground = old_state[3]

		for x in range(WIDTH):
			for y in range(HEIGHT):
				var index = x + y * WIDTH
				set_tile(Vector2i(x, y), state_kind[index], state_info[index])
				set_ground(Vector2i(x, y), state_ground[index])

func reset():
	load_level(current_level)

func _on_text_edit_text_changed():
	current_level[1] = text_edit.text

func _on_level_editor_button_pressed():
	load_level(current_level)

func _on_spin_box_value_changed(value):
	current_level[0] = value
