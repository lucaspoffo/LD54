extends Node

enum Tile {
	NOTHING,
	PLAYER_UP,
	PLAYER_DOWN,
	PLAYER_LEFT,
	PLAYER_RIGHT,
	EXIT,
	FLOWER,
	FLOWER_BLOOMED,
	ROCK,
	WATER,
	ROOT_LEFT,
	ROOT_RIGHT,
	ROOT_UP,
	ROOT_DOWN,
}

var grid: Array[Tile] = []
@onready var tile_map: TileMap = $TileMap
@onready var player: Node = $Player

@onready var text_edit: TextEdit = $LevelEditor/TextEdit

var WIDTH := 9
var HEIGHT := 10

var updating_world := false

var undo_state: Array = []

var level = """
XXXXEXXXX
.........
.........
.........
.........
......FW.
F.....X..
.........
.........
....P....
"""

# Called when the node enters the scene tree for the first time.
func _ready():
	text_edit.text = level
	load_level(level)

func load_level(text: String):
	grid.clear()
	undo_state.clear()
	for x in text:
		match x:
			".":
				grid.push_back(Tile.NOTHING)
			"E":
				grid.push_back(Tile.EXIT)
			"W":
				grid.push_back(Tile.WATER)
			"X":
				grid.push_back(Tile.ROCK)
			"F":
				grid.push_back(Tile.FLOWER)
			"P":
				grid.push_back(Tile.PLAYER_UP)

	undo_state.push_back(grid.duplicate())
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

func player_move(direction: Vector2i):
	var current_pos := player_pos()
	var next_pos := current_pos + direction
	var next_tile := get_tile(next_pos)
	match next_tile:
		Tile.NOTHING, Tile.EXIT:
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
		Tile.EXIT:
			tile_map.set_cell(1, position, 0, Vector2i(2, 4))
		Tile.PLAYER_UP, Tile.PLAYER_DOWN, Tile.PLAYER_LEFT, Tile.PLAYER_RIGHT:
			player.position = tile_map.map_to_local(position)
		Tile.FLOWER:
			tile_map.set_cell(1, position, 0, Vector2i(5, 6))
		Tile.FLOWER_BLOOMED:
			tile_map.set_cell(1, position, 0, Vector2i(6, 5))
		Tile.ROOT_UP, Tile.ROOT_LEFT, Tile.ROOT_RIGHT, Tile.ROOT_DOWN:
			tile_map.set_cell(1, position, 0, Vector2i(4, 1))

func _input(event):
	if updating_world:
		return
	if event.is_action_pressed("show_editor"):
		$LevelEditor.visible = !$LevelEditor.visible
	if event.is_action_pressed("move_up"):
		undo_state.push_back(grid.duplicate())
		player_move(Vector2i.UP)
		update_world()
	if event.is_action_pressed("move_down"):
		undo_state.push_back(grid.duplicate())
		player_move(Vector2i.DOWN)
		update_world()
	if event.is_action_pressed("move_left"):
		undo_state.push_back(grid.duplicate())
		player_move(Vector2i.LEFT)
		update_world()
	if event.is_action_pressed("move_right"):
		undo_state.push_back(grid.duplicate())
		player_move(Vector2i.RIGHT)
		update_world()
	if event.is_action_pressed("undo"):
		undo()
	if event.is_action_pressed("reset"):
		reset()
			

func update_world():
	updating_world = true
	while update_world_tiles():
		await get_tree().create_timer(.1).timeout
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

func undo():
	print(len(undo_state))
	if len(undo_state) > 0:
		var state = undo_state.pop_back()
		for x in range(WIDTH):
			for y in range(HEIGHT):
				var index = x + y * WIDTH
				# print(state[index])
				set_tile(Vector2i(x, y), state[index])
		if len(undo_state) == 0:
			undo_state.push_back(state)

func reset():
	load_level(level)

func _on_text_edit_text_changed():
	level = text_edit.text

func _on_level_editor_button_pressed():
	load_level(level)
