extends Node2D
#[1,  """\
#XXXXEXXXX
#.........
#.........
#.........
#.........
#.........
#.........
#.........
#.........
#....P...."""]

@onready var game: Game = $Game
var levels: Array = [
[1,  """\
XXXXEXXXX
.........
.........
....X....
....W....
.........
....X....
.........
.........
....P...."""],
[1,  """\
XXXXEXXXX
WWWX.XWWW
WWWX.XWWW
WWWX.XWWW
WWWX.XWWW
WWWW.WWWW
WWWX.XWWW
WWWX.XWWW
WWWX.XWWW
WWWXPXWWW"""],
[1,  """\
XXXXXXEXX
.........
.........
.........
....F....
W...X...W
.........
.........
.........
....P...."""],
[4, """\
XXXXEXXXX
...X.X...
.XXX.XXX.
.X.....X.
.X.WXW.X.
.X.XWXdw.X.
.X.WXW.X.
.X.....X.
..XX.XX..
...XPX...
"""],
[2,
"""\
XXXXEXXXX
.........
.........
.........
...F.F...
....W....
...F.F...
.........
.........
....P....
"""
],
#[11,
#"""\
#XXXXEXXXX
#XXX...XXX
#XXX.W.XXX
#X.......X
#XX.X.X.XX
#X.......X
#X.X.X.X.X
#X.......X
#XXX...XXX
#XXXXPXXXX"""
#],
# Should be last? Pretty hard
[2, """\
XXXXEXXXX
.........
.........
.F.....F.
W.......W
W.......W
W.......W
.F.....F.
.........
....P....
"""
],
]

var current_level := 0
var final_level := len(levels) - 1

# Called when the node enters the scene tree for the first time.
func _ready():
	game.load_level(levels[0])

func _on_game_level_completed():
	if current_level == final_level:
		$End.visible = true
		return
	
	current_level += 1
	game.load_level(levels[current_level])
