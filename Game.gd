extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
const TILE_SIZE = 16
const LEVEL_SIZES =[
	Vector2(30, 30),
	Vector2(35, 35),
	Vector2(40, 40),
	Vector2(45, 45),
	Vector2(50, 50)
]

const LEVEL_COLORS = [Color.beige, Color.cadetblue, Color.darkmagenta, Color.goldenrod, Color.lightsalmon, Color.darkgray, Color.lawngreen]
const ENEMY_COLORS = [Color.green, Color.purple, Color.darkslateblue, Color.indigo, Color.orangered, Color.gold]
const LEVEL_ROOM_COUNTS = [5, 7, 9, 12, 15]
const LEVEL_ENEMY_COUNTS = [5, 8, 12, 18, 26]
const LEVEL_ITEM_COUNTS = [2, 4, 6, 8, 10]
const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 8
const PLAYER_START_HP = 10


enum Tile {Door=3, Floor=1, Stair=2, Stone=5, Wall=6, OpenDoor=7}

const EnemyScene = preload("res://Enemy.tscn")
const PotionScene = preload("res://Potions.tscn")
const FoodScene = preload("res://Food.tscn")
const TreasureScene = preload("res://Treasure.tscn")

const FOOD_LEVELS = [5, 6, 7, 0, 1]
const FOOD_COLORS = [Color.darkgoldenrod, Color.antiquewhite, Color.yellow, Color.orange, Color.red]
const TREASURE_LEVELS = [2, 1, 3, 0, 0]
const TREASURE_COLORS = [Color.gold, Color.gold, Color.lightblue, Color.darkkhaki]
const POTION_FUNCTIONS = ["blind", "heal_over_time", "poison", "heal", "strength"]
const POTION_COLORS = [Color.magenta, Color.green, Color.yellow, Color.aqua, Color.blueviolet]

enum ItemEffect {Heal, HealOverTime, Poison, Blind, Strength, Score}
enum ItemType {Potion, Food, Treasure}

const ITEM_CREATION_CHANCES = [
	[ItemType.Treasure, 25],
	[ItemType.Potion, 75],
	[ItemType.Food, 100]
]

const ITEM_DROP_CHANCES = [
	[ItemType.Food, 5],
	[ItemType.Potion, 5],
	[ItemType.Treasure, 15]
]

class Item extends Reference:
	var sprite_node
	var tile
	var type
	var strength
	var use_function
	var discovered = false
	
	func _init(game, x, y, item_type, level):
		tile = Vector2(x, y)
		type = item_type
		strength = (randi() % (level + 1) + 1)
		if type == ItemType.Food:
			sprite_node = FoodScene.instance()
			sprite_node.frame = FOOD_LEVELS[strength - 1]
			sprite_node.modulate = FOOD_COLORS[strength -1]
			use_function = "heal"
		elif type == ItemType.Potion:
			sprite_node = PotionScene.instance()
			sprite_node.modulate = Color.darkolivegreen
			var rand_type = randi() % game.potion_types.size()
			use_function = game.potion_types[rand_type]
			sprite_node.frame = strength - 1
			sprite_node.modulate = game.potion_colors[rand_type]
		elif type == ItemType.Treasure:
			sprite_node = TreasureScene.instance()
			sprite_node.frame = TREASURE_LEVELS[strength - 1]
			sprite_node.modulate = TREASURE_COLORS[strength - 1]
			use_function = "score"
		sprite_node.position = tile * TILE_SIZE
		sprite_node.visible = false
		game.add_child(sprite_node)
			
		
	func remove():
		sprite_node.queue_free()

class Enemy extends Reference:
	var sprite_node
	var tile
	var full_hp
	var hp
	var level
	var dead = false
	var awake = false
	
	func _init(game, enemy_level, x, y):
		full_hp = (1 + enemy_level) * 3 
		level = enemy_level + 1
		hp = full_hp
		tile = Vector2(x, y)
		sprite_node = EnemyScene.instance()
		game.add_child(sprite_node)
		sprite_node.set_sprite(enemy_level)
		sprite_node.modulate_sprite(game.ENEMY_COLORS[enemy_level])
		sprite_node.position = tile * TILE_SIZE
		sprite_node.visible = true
		sprite_node.z_index = 1
	
	func remove():
		sprite_node.queue_free()
		
	func take_damage(game, dmg):
		if dead:
			return
		
		hp = max(0, hp - dmg)
		sprite_node.get_node("HPBar").rect_size.x = TILE_SIZE * hp / full_hp
		
		if hp == 0:
			game.FCTM.show_value("DEADED!!", tile, Color.red)
			dead = true
			game.score += 10 * level
		else:
			game.FCTM.show_value(dmg*-1, tile, Color.red)
			
	func act(game):
		var my_point = game.enemy_pathfinding.get_closest_point(tile)
		var player_point = game.enemy_pathfinding.get_closest_point(game.player_tile)
		var path = game.enemy_pathfinding.get_point_path(my_point, player_point)
		if path:
			assert(path.size() > 1)
			var move_tile = path[1]
			
			if move_tile == game.player_tile:
				game.damage_player(int((1+level) * (max(.5, (randi() % 100)/100 ) ) ) )
			else:
				var blocked = false
				for enemy in game.enemies:
					if enemy.tile == move_tile:
						blocked = true
						break
						
				if !blocked:
					tile = move_tile

var level_num = 0
var map = []
var rooms = []
var level_size
var enemies = []
var player_hp = PLAYER_START_HP
var items = []
var potion_types
var potion_colors
var blind_turns = 0
var healing_turns = 0
var poison_turns = 0
var strong_turns = 0
var player_level = 1
var player_max_hp = 10
var game_stopped = true

var enemy_pathfinding

onready var tile_map = $TileMap
onready var visibility_map = $VisibilityMap
onready var fow_map = $FogOfWar
onready var player = $Player
onready var FCTM = $FCTManager

var player_tile

var score = 0 
# Called when the node enters the scene tree for the first time.
func _ready():
	OS.set_window_size(Vector2(1280, 720))
	randomize()
	build_level()
	
func _input(event):
	if !event.is_pressed() && !(event is InputEventMouseButton):
		return
	if game_stopped:
		return
	if event.is_action("Left"):
		try_move(-1, 0)
	elif event.is_action("Right"):
		try_move(1, 0)
	elif event.is_action("Up"):
		try_move(0, -1)
	elif event.is_action("Down"):
		try_move(0, 1)
	elif event is InputEventMouseButton && !event.is_echo():
		var mouse_loc = get_global_mouse_position()/16
		var direction = tile_direction(player_tile, mouse_loc)
		if direction.x != 0 && direction.y != 0:
			if randi() % 2 == 0:
				direction = Vector2(direction.x, 0)
			else:
				direction = Vector2(0, direction.y)
		try_move(direction.x * -1, direction.y * -1)

func try_move(dx, dy):
	var x = player_tile.x + clamp(dx, -1, 1)
	var y = player_tile.y + clamp(dy, -1, 1)
	
	var tile_type = Tile.Stone
	if x >= 0 && x < level_size.x && y >= 0 && y < level_size.y:
		tile_type = map[x][y]
	var acted = false
	if blind_turns > 0:
		blind_turns -= 1
	
	if poison_turns > 0:
		if player_hp > 1:
			damage_player(1)
		poison_turns -= 1
		
	if healing_turns > 0:
		heal_player(2)
		healing_turns -= 1
	
	if blind_turns > 0:
		blind_turns -= 1
		
	if strong_turns >0:
		strong_turns -= 1

	match tile_type:
		Tile.Floor:
			acted = do_move(x, y)

		Tile.OpenDoor:
			acted = do_move(x, y)
		
		Tile.Door:
			acted = set_tile(x, y, Tile.OpenDoor)
			clear_path(Vector2(x,y))
			
		Tile.Stair:
			level_num += 1
			score += 20
			if level_num < LEVEL_SIZES.size():
				build_level()
			else:
				score += 1000
				$CanvasLayer/Win.visible = true
				game_stopped = true
				
	for enemy in enemies:
		enemy.act(self)
		
	call_deferred("update_visuals")
	
func do_move(x, y):
	var blocked = false
	for enemy in enemies:
		if enemy.tile.x == x && enemy.tile.y == y:
			enemy.take_damage(self, max(1, int(player_level/2)) * (1 if strong_turns == 0 else 2))
			if enemy.dead:
				var drop_item = random_item_type(ITEM_DROP_CHANCES) if enemy.level < 5 else random_item_type(ITEM_CREATION_CHANCES)
				if drop_item:
					for item in items:
						if item.tile == enemy.tile:
							blocked = true
					if !blocked:
						items.append(Item.new(self, enemy.tile.x, enemy.tile.y, drop_item, enemy.level))
				enemy.remove()
				enemies.erase(enemy)
				return true
			else:
				return true
	player_tile = Vector2(x, y)
	pickup_items()
	
func pickup_items():
	var remove_queue = []
	for item in items:
		if item.tile == player_tile:
			if item.use_function == "heal" and player_hp == player_max_hp:
				continue
			call(item.use_function, item)
			item.remove()
			remove_queue.append(item)
	
	for item in remove_queue:
		items.erase(item)
			
			
func random_item_type(chance_list):
	for chance in chance_list:
		if randi()%100 < chance[1]:
			return chance[0]
	return null
	
func blind(item):
	FCTM.show_value("Anti-Carrot Poition!", player_tile, Color.orange)
	blind_turns = item.strength * (1+(randi() % 2)) * 5
	$CanvasLayer/Blind.visible = true
	$Player/BlindEffect.visible = true

func heal_over_time(item):
	FCTM.show_value("Ivermectin!", player_tile, Color.pink)
	healing_turns = item.strength * (1+(randi() % 2)) * 3
	$CanvasLayer/Healing.visible = true
	
func poison(item):
	FCTM.show_value("Gross!", player_tile, Color.darkgreen)
	poison_turns = item.strength * (1+(randi() % 2)) * 3
	$CanvasLayer/Poisoned.visible = true
	
func strength(item):
	FCTM.show_value("Super Male Vitality!", player_tile, Color.gold)
	strong_turns = item.strength * (1+(randi() % 2)) * 10
	$CanvasLayer/Strong.visible = true

func heal(item):
	heal_player(item.strength * 5)
	
func score(item):
	score += item.strength * 25
	
func build_level():
	rooms.clear()
	map.clear()
	tile_map.clear()
	for enemy in enemies:
		enemy.remove()
	for item in items:
		item.remove()
	items.clear()
	enemies.clear()
	
	tile_map.modulate = LEVEL_COLORS[int(randi() % LEVEL_COLORS.size())]
		
	enemy_pathfinding = AStar2D.new()
	
	level_size = LEVEL_SIZES[level_num]
	
	if !potion_types:
		potion_types = POTION_FUNCTIONS.duplicate()
		potion_colors = POTION_COLORS.duplicate()
		potion_types.shuffle()
		potion_colors.shuffle()
		for x in range(-50, LEVEL_SIZES[-1].x + 50):
			for y in range(-50, LEVEL_SIZES[-1].y + 50):
				visibility_map.set_cell(x,y,0)
				fow_map.set_cell(x,y,0)
	
	for x in range(level_size.x):
		map.append([])
		for y in range(level_size.y):
			map[x].append(Tile.Stone)
			tile_map.set_cell(x, y, Tile.Stone)
			visibility_map.set_cell(x, y, 0)

	var free_regions = [Rect2(Vector2(2,2), level_size - Vector2(4, 4))]
	var num_rooms = LEVEL_ROOM_COUNTS[level_num]
	for i in range(num_rooms):
		add_room(free_regions)
		if free_regions.empty():
			break
			
	connect_rooms()
			
	var start_room = rooms.front()
	var player_x = start_room.position.x + 1 + randi() % int(start_room.size.x - 2)
	var player_y = start_room.position.y + 1 + randi() % int(start_room.size.y - 2)
	
	player_tile = Vector2(player_x, player_y)
	
	var num_enemies = LEVEL_ENEMY_COUNTS[level_num]
	for i in range(num_enemies):
		var room = rooms[1 + randi() % (rooms.size() - 1)]
		var x = room.position.x + 1 + randi() % int(room.size.x - 2)
		var y = room.position.y + 1 + randi() % int(room.size.y - 2)
		
		var blocked = false
		for enemy in enemies:
			if enemy.tile.x == x && enemy.tile.y == y:
				blocked = true
				break
		
		if !blocked:
			var enemy = Enemy.new(self, randi() % (level_num + 1), x, y)
			enemies.append(enemy)
			
	var num_items = LEVEL_ITEM_COUNTS[level_num]
	for i in range(num_items):
		var place_tries = 0
		var blocked = true
		while blocked and place_tries < 10:
			blocked = false
			var room = rooms[randi() % (rooms.size())]
			var x = room.position.x + 1 + randi() % int(room.size.x - 2)
			var y = room.position.y + 1 + randi() % int(room.size.y - 2)
			for item in items:
				if item.tile.x == x && item.tile.y == y:
					blocked = true
					break
			if map[x][y] == Tile.Stair or map[x][y] == Tile.Wall or map[x][y] == Tile.Stone:
				blocked = true
			if !blocked && x != player_tile.x && y != player_tile.y:
				var item_type = random_item_type(ITEM_CREATION_CHANCES)
				items.append(Item.new(self, x, y, item_type, level_num))
				items[items.size()-1].sprite_node.visible = false
			place_tries += 1
	
	call_deferred("update_visuals")
	
	var end_room = rooms.back()
	
	var stair_x = end_room.position.x + 1 + randi() % int(end_room.size.x - 2)
	var stair_y = end_room.position.y + 1 + randi() % int(end_room.size.y - 2)
	set_tile(stair_x, stair_y, Tile.Stair)
	
	game_stopped = false
	
	$CanvasLayer/Level.text = "Floor: " + str(level_num + 1)
	#tile_map.update_bitmask_region(Vector2(1,1), Vector2(level_size.x - 1, level_size.y - 1))

func clear_path(tile):
	var new_point = enemy_pathfinding.get_available_point_id()
	enemy_pathfinding.add_point(new_point, Vector2(tile.x, tile.y))
	var points_to_connect = []
	
	if tile.x > 0 && ( map[tile.x - 1][tile.y] == Tile.Floor || map[tile.x - 1][tile.y] == Tile.OpenDoor ):
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector2(tile.x - 1, tile.y)))
	if tile.y > 0 && ( map[tile.x][tile.y - 1] == Tile.Floor || map[tile.x][tile.y - 1] == Tile.OpenDoor ):
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector2(tile.x, tile.y - 1)))
	if tile.x < level_size.x - 1 && ( map[tile.x + 1][tile.y] == Tile.Floor || map[tile.x + 1][tile.y] == Tile.OpenDoor ):
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector2(tile.x + 1, tile.y)))
	if tile.y < level_size.y - 1 && ( map[tile.x][tile.y + 1] == Tile.Floor || map[tile.x][tile.y + 1] == Tile.OpenDoor ):
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector2(tile.x, tile.y + 1)))
		
	for point in points_to_connect:
		enemy_pathfinding.connect_points(point, new_point)

func update_visuals():
	player.position = player_tile * TILE_SIZE
	yield(get_tree(), "idle_frame")
	var player_center = tile_to_pixel_center(player_tile.x, player_tile.y)
	var space_state = get_world_2d().direct_space_state
	for x in range(level_size.x):
		for y in range(level_size.y):
			var direction = tile_direction(player_tile, Vector2(x, y))
			var test_point = tile_to_pixel_center(x, y) + direction * TILE_SIZE / 2
		
			var occlusion = space_state.intersect_ray(player_center, test_point)
			if !occlusion || (occlusion.position - test_point).length() < 1:
				visibility_map.set_cell(x, y, -1)
				fow_map.set_cell(x,y,-1)
			else:
				fow_map.set_cell(x,y,0)
			
					
	for enemy in enemies:
		enemy.sprite_node.position = enemy.tile * TILE_SIZE
		var enemy_center = tile_to_pixel_center(enemy.tile.x, enemy.tile.y)
		var occlusion = space_state.intersect_ray(player_center, enemy_center)
		if occlusion:
			enemy.sprite_node.visible = false
		else:
			enemy.sprite_node.visible = true
			enemy.awake = true
			
	for item in items:
		item.sprite_node.position = item.tile * TILE_SIZE
		var item_center = tile_to_pixel_center(item.tile.x, item.tile.y)
		var occlusion = space_state.intersect_ray(player_center, item_center)
		if !occlusion:
			item.sprite_node.visible = true
			item.discovered = true
		elif !item.discovered:
			item.sprite_node.visible = false
	
	var cur_level = calc_player_level()
	if cur_level > player_level:
		FCTM.show_value("LEVEL UP!", player_tile, Color.blue)
		player_level = cur_level
		player_hp += calc_player_max_hp() - player_max_hp
		player_max_hp = calc_player_max_hp()
					
	$CanvasLayer/HP.text = "HP: " + str(player_hp) + "/" + str(player_max_hp)
	$CanvasLayer/Score.text = "Score: " + str(score)
	$CanvasLayer/Player_Level.text = "Level: " + str(player_level)
	if blind_turns > 0:
		$CanvasLayer/Blind.text = "Blind: " + str(blind_turns)
	else:
		$CanvasLayer/Blind.visible = false
		$Player/BlindEffect.visible = false
	if poison_turns > 0:
		$CanvasLayer/Poisoned.text = "Poisoned: " + str(poison_turns)
	else:
		$CanvasLayer/Poisoned.visible = false
	if healing_turns > 0:
		$CanvasLayer/Healing.text = "Healing: " + str(healing_turns)
	else:
		$CanvasLayer/Healing.visible = false
	if strong_turns > 0:
		$CanvasLayer/Strong.text = "STRONGK: " + str(strong_turns)
	else:
		$CanvasLayer/Strong.visible = false
		
	
func tile_direction(from_tile, to_tile):
	return Vector2(1 if to_tile.x < from_tile.x else -1, 1 if to_tile.y < from_tile.y else -1)

func tile_to_pixel_center(x, y):
	return Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)

func connect_rooms():
	var stone_graph = AStar2D.new()
	var point_id = 0
	for x in range(level_size.x):
		for y in range(level_size.y):
			if map[x][y] == Tile.Stone:
				stone_graph.add_point(point_id, Vector2(x,y))
				
				if x > 0 && map[x -1 ][y] == Tile.Stone:
					var left_point = stone_graph.get_closest_point(Vector2(x - 1, y))
					stone_graph.connect_points(point_id, left_point)
					
				if y > 0 && map[x][y - 1] == Tile.Stone:
					var above_point = stone_graph.get_closest_point(Vector2(x, y - 1))
					stone_graph.connect_points(point_id, above_point)
					
				point_id += 1
				
	var room_graph = AStar2D.new()
	point_id = 0
	for room in rooms:
		var room_center = room.position + room.size / 2
		room_graph.add_point(point_id, Vector2(room_center.x, room_center.y))
		point_id += 1
		
	while !is_everything_connected(room_graph):
		add_random_connection(stone_graph, room_graph)
		
func is_everything_connected(graph):
	var points = graph.get_points()
	var start = points.pop_back()
	for point in points:
		var path = graph.get_point_path(start, point)
		if !path:
			return false
			
	return true

func add_random_connection(stone_graph, room_graph):
	var start_room_id = get_least_connected_point(room_graph)
	var end_room_id = get_nearest_unconnected_point(room_graph, start_room_id)
	
	var start_position = pick_random_door_location(rooms[start_room_id])
	var end_position = pick_random_door_location(rooms[end_room_id])
	
	var closest_start_point = stone_graph.get_closest_point(start_position)
	var closest_end_point = stone_graph.get_closest_point(end_position)
	
	var path = stone_graph.get_point_path(closest_start_point, closest_end_point)
	assert(path)
	
	set_tile(start_position.x, start_position.y, Tile.Door)
	set_tile(end_position.x, end_position.y, Tile.Door)
	
	for position in path:
		set_tile(position.x, position.y, Tile.Floor)
		
	room_graph.connect_points(start_room_id, end_room_id)
	
func get_least_connected_point(graph):
	var point_ids = graph.get_points()
	
	var least
	var tied_for_least = []
	
	for point in point_ids:
		var count = graph.get_point_connections(point).size()
		if least == null || count < least:
			least = count
			tied_for_least = [point]
		elif count == least:
			tied_for_least.append(point)
			
	return tied_for_least[randi() % tied_for_least.size()]
		
func get_nearest_unconnected_point(graph, target_point):
	var target_position = graph.get_point_position(target_point)
	var point_ids = graph.get_points()
	
	var nearest
	var tied_for_nearest = []
	
	for point in point_ids:
		if point == target_point:
			continue
			
		var path = graph.get_point_path(point, target_point)
		if path:
			continue
		
		var dist = (graph.get_point_position(point) - target_position).length()
		if !nearest || dist < nearest:
			nearest = dist
			tied_for_nearest = [point]
		elif dist == nearest:
			tied_for_nearest.append(point)
	
	return tied_for_nearest[randi() % tied_for_nearest.size()]

func pick_random_door_location(room):
	var options = []
	
	for x in range(room.position.x + 1, room.end.x -2):
		options.append(Vector2(x, room.position.y))
		options.append(Vector2(x, room.end.y -1))
		
	for y in range(room.position.y + 1, room.end.y - 2):
		options.append(Vector2(room.position.x, y))
		options.append(Vector2(room.end.x - 1, y))
		
	return options[randi() % options.size()]

func add_room(free_regions):
	var region = free_regions[randi() % free_regions.size()]

	var size_x = MIN_ROOM_DIMENSION
	if region.size.x > MIN_ROOM_DIMENSION:
		size_x += randi() % int(region.size.x - MIN_ROOM_DIMENSION)
		
	var size_y = MIN_ROOM_DIMENSION
	if region.size.y > MIN_ROOM_DIMENSION:
		size_y += randi() % int(region.size.y - MIN_ROOM_DIMENSION)
		
	size_x = min(size_x, MAX_ROOM_DIMENSION)
	size_y = min(size_y, MAX_ROOM_DIMENSION)
	
	var start_x = region.position.x
	if region.size.x > size_x:
		start_x += randi() % int(region.size.x - size_x)
		
	var start_y = region.position.y
	if region.size.y > size_y:
		start_y += randi() % int(region.size.y - size_y)
	
	var room = Rect2(start_x, start_y, size_x, size_y)
	rooms.append(room)
	
	for x in range(start_x, start_x + size_x):
		set_tile(x, start_y, Tile.Wall)
		set_tile(x, start_y + size_y - 1, Tile.Wall)
		
	for y in range(start_y + 1, start_y + size_y - 1):
		set_tile(start_x, y, Tile.Wall)
		set_tile(start_x + size_x - 1, y, Tile.Wall)
		
		for x in range(start_x + 1, start_x + size_x - 1):
			set_tile(x, y, Tile.Floor)
			
	cut_regions(free_regions, room)
	
func cut_regions(free_regions, region_to_remove):
	var removal_queue = []
	var addition_queue = []
	
	for region in free_regions:
		if region.intersects(region_to_remove):
			removal_queue.append(region)
			
			var leftover_left = region_to_remove.position.x - region.position.x - 1
			var leftover_right = region.end.x - region_to_remove.end.x - 1
			var leftover_above = region_to_remove.position.y - region.position.y - 1
			var leftover_below = region.end.y - region_to_remove.end.y - 1
			
			if leftover_left >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(region.position, Vector2(leftover_left, region.size.y)))
			if leftover_right >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(Vector2(region_to_remove.end.x + 1, region.position.y), Vector2(leftover_right, region.size.y)))
			if leftover_above >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(region.position, Vector2(region.size.x, leftover_above)))
			if leftover_below >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(Vector2(region.position.x, region_to_remove.end.y + 1), Vector2(region.size.x, leftover_below)))
				
	for region in removal_queue:
		free_regions.erase(region)
		
	for region in addition_queue:
		free_regions.append(region)
		
func set_tile(x, y, type):
	map[x][y] = type
	tile_map.set_cell(x, y, type)
	
	if type == Tile.Floor || type == Tile.OpenDoor:
		clear_path(Vector2(x,y))
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func damage_player(dmg):
	FCTM.show_value(dmg*-1, player_tile, Color.red)
	player_hp = max(0, player_hp - dmg)
	if player_hp == 0:
		$CanvasLayer/Lose.visible = true
		poison_turns = 0
		strong_turns = 0
		blind_turns = 0
		strong_turns = 0
		game_stopped = true

func calc_player_level():
	return floor(score/100) + 1

func calc_player_max_hp():
	return (player_level * 5) + 5

func heal_player(heal):
	if player_hp < player_max_hp:
		var hpdiff = player_max_hp - player_hp
		var heal_amount = min(hpdiff, heal)
		FCTM.show_value(heal_amount, player_tile, Color.pink)
		player_hp += heal_amount

func _on_Button_pressed():
	level_num = 0
	score = 0
	potion_types = POTION_FUNCTIONS.duplicate()
	potion_types.shuffle()
	build_level()
	$CanvasLayer/Win.visible = false
	$CanvasLayer/Lose.visible = false
	player_max_hp = calc_player_max_hp()
	player_hp = player_max_hp
	player_level = calc_player_level()
