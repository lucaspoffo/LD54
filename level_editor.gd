extends Node

@onready var tile_buttons = {
	Game.Tile_Kind.FLOWER: $Panel/GridContainer/Flower,
	Game.Ground_Kind.WATER: $Panel/GridContainer/Water,
	Game.Ground_Kind.GROUND: $Panel/GridContainer/Ground,
	Game.Tile_Kind.ROCK: $Panel/GridContainer/Rock,
	Game.Tile_Kind.EXIT_CLOSED: $Panel/GridContainer/Gate,
	Game.Tile_Kind.BIG_CRATE: $Panel/GridContainer/Crate,
	Game.Tile_Kind.NOTHING: $Panel/GridContainer/Remove,
}

@onready var select_rect = $Panel/GridContainer/Ground/Selected 
var current_selected_tile: int = Game.Ground_Kind.GROUND
@export var game: Game
var editor_enabled = false

func _ready():
	select_tile(current_selected_tile)

func place_tile(position: Vector2i):
	if game.level_resource == null:
		return
		
	if position.x >= game.WIDTH || position.y >= game.HEIGHT || position.x < 0 || position.y < 0:
		return

	var index := position.x + position.y * game.WIDTH
	match current_selected_tile:
		Game.Ground_Kind.GROUND, Game.Tile_Kind.NOTHING:
			game.level_resource.grid_ground[index] = Game.Ground_Kind.GROUND
			game.level_resource.grid_info[index] = null
			game.set_ground(position, Game.Ground_Kind.GROUND)
		Game.Ground_Kind.WATER:
			game.level_resource.grid_ground[index] = Game.Ground_Kind.WATER
			game.level_resource.grid_info[index] = null
			game.level_resource.grid_kind[index] = Game.Tile_Kind.NOTHING
			game.set_ground(position, Game.Ground_Kind.WATER)
		Game.Tile_Kind.FLOWER:
			game.level_resource.grid_ground[index] = Game.Ground_Kind.GROUND
			game.level_resource.grid_info[index] = null
			game.level_resource.grid_kind[index] = Game.Tile_Kind.FLOWER
			game.set_tile(position, Game.Tile_Kind.FLOWER)
		Game.Tile_Kind.ROCK:
			game.level_resource.grid_ground[index] = Game.Ground_Kind.GROUND
			game.level_resource.grid_info[index] = null
			game.level_resource.grid_kind[index] = Game.Tile_Kind.ROCK
			game.set_tile(position, Game.Tile_Kind.ROCK)
		Game.Tile_Kind.EXIT_CLOSED:
			game.level_resource.grid_ground[index] = Game.Ground_Kind.GROUND
			game.level_resource.grid_info[index] = null
			game.level_resource.grid_kind[index] = Game.Tile_Kind.EXIT_CLOSED
			game.set_tile(position, Game.Tile_Kind.EXIT_CLOSED)
		Game.Tile_Kind.BIG_CRATE:
			game.level_resource.grid_ground[index] = Game.Ground_Kind.GROUND
			game.level_resource.grid_info[index] = null
			game.level_resource.grid_kind[index] = Game.Tile_Kind.BIG_CRATE
			game.set_tile(position, Game.Tile_Kind.BIG_CRATE)

func select_tile(tile) -> void:
	tile_buttons[current_selected_tile].remove_child(select_rect)
	current_selected_tile = tile
	tile_buttons[current_selected_tile].add_child(select_rect)

func _input(event):
	if !editor_enabled: return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			select_tile(Game.Ground_Kind.GROUND)
		if event.keycode == KEY_2:
			select_tile(Game.Ground_Kind.WATER)
		if event.keycode == KEY_3:
			select_tile(Game.Tile_Kind.NOTHING)
		if event.keycode == KEY_Q:
			select_tile(Game.Tile_Kind.FLOWER)
		if event.keycode == KEY_W:
			select_tile(Game.Tile_Kind.ROCK)
		if event.keycode == KEY_E:
			select_tile(Game.Tile_Kind.BIG_CRATE)
		if event.keycode == KEY_R:
			select_tile(Game.Tile_Kind.EXIT_CLOSED)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
			var tile_pos := game.tile_map.local_to_map(game.tile_map.get_local_mouse_position())
			place_tile(tile_pos)
