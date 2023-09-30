extends Node

class_name Game

enum Tile {
	NOTHING,
	PLAYER_UP,
	PLAYER_DOWN,
	PLAYER_LEFT,
	PLAYER_RIGHT,
	EXIT_CLOSED,
	EXIT_OPENED,
	FLOWER,
	FLOWER_BLOOMED,
	ROCK,
	WATER,
	ROOT_LEFT,
	ROOT_RIGHT,
	ROOT_UP,
	ROOT_DOWN,
}

signal level_completed

var grid: Array[Tile] = []
var flower_seeds := 0:
	get:
		return flower_seeds
	set(value):
		flower_seeds_label.text = str(value)
		flower_seeds = value

@onready var tile_map: TileMap = $TileMap
@onready var player: Node = $Player
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
......FW.
F.....X..
.........
X........
....P...."""]

# Called when the node enters the scene tree for the first time.
func _ready():
	text_edit.text = current_level[1]

func load_level(level: Array):
	level_complete = false
	updating_world = false
	grid.clear()
	undo_state.clear()
	flower_seeds = level[0]
	var text = level[1]
	text_edit.text = text
	for x in text:
		match x:
			".":
				grid.push_back(Tile.NOTHING)
			"E":
				grid.push_back(Tile.EXIT_CLOSED)
			"W":
				grid.push_back(Tile.WATER)
			"X":
				grid.push_back(Tile.ROCK)
			"F":
				grid.push_back(Tile.FLOWER)
			"P":
				grid.push_back(Tile.PLAYER_UP)
	print(len(grid))
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var index = x + y * WIDTH
			set_tile(Vector2i(x, y), grid[index])
				

func player_pos() -> Vector2i:
	for i in grid.size():
		if grid[i] == Tile.PLAYER_UP or grid[i] == Tile.PLAYER_DOWN or grid[i] == Tile.PLAYER_LEFT or grid[i] == Tile.PLAYER_RIGHT:
			return Vector2i(i % WIDTH, i / WIDTH)
	
	push_error("Player not found")
	return Vector2i.ZERO
	
func exit_pos() -> Vector2i:
	for i in grid.size():
		if grid[i] == Tile.EXIT_CLOSED or grid[i] == Tile.EXIT_OPENED:
			return Vector2i(i % WIDTH, i / WIDTH)
	
	push_error("Exit not found")
	return Vector2i.ZERO

func player_can_move(direction: Vector2i) -> bool:
	var next_pos := player_pos() + direction
	var next_tile := get_tile(next_pos)
	match next_tile:
		Tile.NOTHING, Tile.EXIT_OPENED:
			return true
	return false

func can_place_flower(pos: Vector2i) -> bool:
	var tile := get_tile(pos)
	match tile:
		Tile.NOTHING:
			return true
	return false
	
func player_move(direction: Vector2i):
	var current_pos := player_pos()
	var next_pos := current_pos + direction
	var next_tile := get_tile(next_pos)
	match next_tile:
		Tile.NOTHING:
			player.position = $TileMap.map_to_local(next_pos)
			match direction:
				Vector2i.UP:
					set_tile(next_pos, Tile.PLAYER_UP)
				Vector2i.DOWN:
					set_tile(next_pos, Tile.PLAYER_DOWN)
				Vector2i.LEFT:
					set_tile(next_pos, Tile.PLAYER_LEFT)
				Vector2i.RIGHT:
					set_tile(next_pos, Tile.PLAYER_RIGHT)
			set_tile(current_pos, Tile.NOTHING)
		Tile.EXIT_OPENED:
			set_tile(next_pos, Tile.PLAYER_UP)
			level_complete = true
	
func get_tile(position: Vector2i) -> Tile:
	if position.x < 0 or position.x >= WIDTH or position.y < 0 or position.y >= HEIGHT:
		return Tile.ROCK
	var index = position.x + position.y * WIDTH
	return grid[index]
	
func set_tile(position: Vector2i, tile: Tile):
	var index = position.x + position.y * WIDTH
	grid[index] = tile
	match tile:
		Tile.NOTHING:
			tile_map.set_cell(1, position, -1)
		Tile.WATER:
			tile_map.set_cell(1, position, 0, Vector2i(3, 2))
		Tile.ROCK:
			tile_map.set_cell(1, position, 0, Vector2i(3, 5))
		Tile.EXIT_CLOSED:
			tile_map.set_cell(1, position, 0, Vector2i(2, 4))
		Tile.EXIT_OPENED:
			tile_map.set_cell(1, position, 0, Vector2i(7, 1))
		Tile.PLAYER_UP, Tile.PLAYER_DOWN, Tile.PLAYER_LEFT, Tile.PLAYER_RIGHT:
			player.position = tile_map.map_to_local(position)
		Tile.FLOWER:
			tile_map.set_cell(1, position, 0, Vector2i(5, 6))
		Tile.FLOWER_BLOOMED:
			tile_map.set_cell(1, position, 0, Vector2i(6, 5))
		Tile.ROOT_UP, Tile.ROOT_LEFT, Tile.ROOT_RIGHT, Tile.ROOT_DOWN:
			tile_map.set_cell(1, position, 0, Vector2i(4, 1))

func _input(event):
	if updating_world || level_complete:
		return
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
	# Use a copy of grid to not update things added onaaaaaadaww this tick
	var grid_copy := grid.duplicate()
	for i in grid_copy.size():
		var pos = Vector2i(i % WIDTH, i / WIDTH)
		match grid_copy[i]:
			Tile.FLOWER:
				var next_to_water = has_water_for_flower(pos + Vector2i.UP) or \
									has_water_for_flower(pos + Vector2i.DOWN) or \
									has_water_for_flower(pos + Vector2i.LEFT) or \
									has_water_for_flower(pos + Vector2i.RIGHT)
				if next_to_water:
					set_tile(pos, Tile.FLOWER_BLOOMED)
					update_again = true
			Tile.FLOWER_BLOOMED:
				if get_tile(pos + Vector2i.UP) == Tile.NOTHING:
					set_tile(pos + Vector2i.UP, Tile.ROOT_UP)
					update_again = true
				if get_tile(pos + Vector2i.DOWN) == Tile.NOTHING:
					set_tile(pos + Vector2i.DOWN, Tile.ROOT_DOWN)
					update_again = true
				if get_tile(pos + Vector2i.LEFT) == Tile.NOTHING:
					set_tile(pos + Vector2i.LEFT, Tile.ROOT_LEFT)
					update_again = true
				if get_tile(pos + Vector2i.RIGHT) == Tile.NOTHING:
					set_tile(pos + Vector2i.RIGHT, Tile.ROOT_RIGHT)
					update_again = true
			Tile.ROOT_UP:
				if get_tile(pos + Vector2i.UP) == Tile.NOTHING:
					set_tile(pos + Vector2i.UP, Tile.ROOT_UP)
					update_again = true
			Tile.ROOT_DOWN:
				if get_tile(pos + Vector2i.DOWN) == Tile.NOTHING:
					set_tile(pos + Vector2i.DOWN, Tile.ROOT_DOWN)
					update_again = true
			Tile.ROOT_LEFT:
				if get_tile(pos + Vector2i.LEFT) == Tile.NOTHING:
					set_tile(pos + Vector2i.LEFT, Tile.ROOT_LEFT)
					update_again = true
			Tile.ROOT_RIGHT:
				if get_tile(pos + Vector2i.RIGHT) == Tile.NOTHING:
					set_tile(pos + Vector2i.RIGHT, Tile.ROOT_RIGHT)
					update_again = true
	
	return update_again

func has_water_for_flower(pos: Vector2i) -> bool:
	var tile := get_tile(pos)
	match tile:
		Tile.WATER, Tile.ROOT_UP, Tile.ROOT_LEFT, Tile.ROOT_RIGHT, Tile.ROOT_DOWN:
			return true
			
	return false

func move(direction: Vector2i):
	if player_can_move(direction):
		undo_state.push_back([flower_seeds, grid.duplicate()])
		player_move(direction)
		await update_world()
		check_open_gate()
		if level_complete:
			level_completed.emit()

func place_flower():
	if flower_seeds == 0:
		return
	
	var direction := Vector2i.UP
	for x in grid:
		match x:
			Tile.PLAYER_UP:
				direction = Vector2i.UP
			Tile.PLAYER_DOWN:
				direction = Vector2i.DOWN
			Tile.PLAYER_LEFT:
				direction = Vector2i.LEFT
			Tile.PLAYER_RIGHT:
				direction = Vector2i.RIGHT
	var flower_pos := player_pos() + direction
	if can_place_flower(flower_pos):
		undo_state.push_back([flower_seeds, grid.duplicate()])
		flower_seeds -= 1
		set_tile(flower_pos, Tile.FLOWER)
		await update_world()
		check_open_gate()

func check_open_gate():
	# If exit already open or won, do nothing
	if exit_opened() || level_complete:
		return
	
	var all_flowers_bloomed = true
	for x in grid:
		if x == Tile.FLOWER:
			all_flowers_bloomed = false
	if flower_seeds == 0 and all_flowers_bloomed:
		set_tile(exit_pos(), Tile.EXIT_OPENED)

func exit_opened():
	for x in grid:
		if x == Tile.EXIT_OPENED:
			return true
	return false

func undo():
	if len(undo_state) > 0:
		var state = undo_state.pop_back()
		var level = state[1]
		flower_seeds = state[0]
		for x in range(WIDTH):
			for y in range(HEIGHT):
				var index = x + y * WIDTH
				set_tile(Vector2i(x, y), level[index])

func reset():
	load_level(current_level)

func _on_text_edit_text_changed():
	current_level[1] = text_edit.text

func _on_level_editor_button_pressed():
	load_level(current_level)

func _on_spin_box_value_changed(value):
	current_level[0] = value
