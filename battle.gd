class_name Battle
extends Control
## Módulo de batalha. O main.gd instancia, chama start() e escuta "finished".

signal finished(won: bool)

enum State { PLAYER_TURN, ENEMY_TURN, CHECK_END, WIN, LOSE }

const HEAL_AMOUNT := 10

var state: State = State.PLAYER_TURN
var grana := 1
var party: Array = []
var enemy: Dictionary = {}
var enemy_hp := 0
var pattern: Array = []
var pattern_i := 0
var stunned := false
var enraged := false
var actor_i := 0
var log_lines: Array[String] = []

var party_ui: Array = []
var enemy_rect: ColorRect
var enemy_label: Label
var intent_label: Label
var grana_label: Label
var actor_label: Label
var log_label: Label
var result_label: Label
var btn_attack: Button
var btn_special: Button
var btn_continue: Button


func _ready() -> void:
	randomize()
	_build_ui()


# =====================================================
#  ENTRADA
# =====================================================
func start(party_ids: Array, enemy_index: int) -> void:
	grana = 1
	pattern_i = 0
	stunned = false
	enraged = false
	party.clear()
	for id in party_ids:
		var c: Dictionary = GameData.roster[id].duplicate()
		c["hp"] = c["max_hp"]
		party.append(c)
	_build_party_ui()

	enemy = GameData.enemies[enemy_index]
	enemy_hp = enemy["hp"]
	pattern = enemy["pattern"]
	enemy_rect.color = enemy["color"]
	_log("%s apareceu!" % enemy["name"])
	actor_i = _next_alive(-1)
	_player_turn()


# =====================================================
#  MÁQUINA DE ESTADOS
# =====================================================
func _player_turn() -> void:
	state = State.PLAYER_TURN
	_refresh()


func _finish_action() -> void:
	state = State.CHECK_END
	_refresh()
	await _wait(0.5)
	_check_end(true)


func _enemy_turn() -> void:
	state = State.ENEMY_TURN
	_refresh()
	await _wait(0.7)
	if stunned:
		stunned = false
		_log("%s perdeu o turno!" % enemy["name"])
	else:
		var info := _attack_info(pattern[pattern_i % pattern.size()])
		for h in info["hits"]:
			if _alive_count() == 0:
				break
			var t := _random_alive()
			_hurt(t, info["dmg"])
			_log("%s acerta %s: %d." % [enemy["name"], party[t]["name"], info["dmg"]])
			await _wait(0.35)
	pattern_i += 1
	_refresh()
	await _wait(0.6)
	_check_end(false)


func _check_end(from_player: bool) -> void:
	state = State.CHECK_END
	if enemy_hp <= 0:
		_end_battle(true)
		return
	if _alive_count() == 0:
		_end_battle(false)
		return
	_try_enrage()
	if from_player:
		var nxt := _next_alive(actor_i)
		if nxt == -1:
			_enemy_turn()
		else:
			actor_i = nxt
			_player_turn()
	else:
		actor_i = _next_alive(-1)
		_player_turn()


func _try_enrage() -> void:
	if enraged or not enemy.has("phase2"):
		return
	if enemy_hp <= enemy["hp"] / 2.0:
		enraged = true
		pattern = enemy["phase2"]
		pattern_i = 0
		_log("%s entrou em FÚRIA!" % enemy["name"])
		_flash(enemy_rect)


func _end_battle(won: bool) -> void:
	state = State.WIN if won else State.LOSE
	result_label.text = "VITÓRIA!" if won else "DERROTA..."
	result_label.visible = true
	btn_continue.visible = true
	if won:
		create_tween().tween_property(enemy_rect, "modulate:a", 0.15, 0.5)
	_log("Você venceu!" if won else "O grupo foi apagado...")
	_refresh()


func _on_continue() -> void:
	finished.emit(state == State.WIN)


func _attack_info(kind: String) -> Dictionary:
	match kind:
		"s":
			return {"dmg": enemy["strong"], "hits": 1, "label": "FORTE"}
		"d":
			return {"dmg": enemy["weak"], "hits": 2, "label": "DUPLO"}
		_:
			return {"dmg": enemy["weak"], "hits": 1, "label": "fraco"}


# =====================================================
#  AÇÕES DO JOGADOR
# =====================================================
func _on_attack() -> void:
	if state != State.PLAYER_TURN:
		return
	var c: Dictionary = party[actor_i]
	_damage_enemy(c["dmg"])
	grana = mini(grana + 1, GameData.MAX_GRANA)
	_log("%s ataca: %d de dano. +1 Grana." % [c["name"], c["dmg"]])
	_finish_action()


func _on_special() -> void:
	if state != State.PLAYER_TURN:
		return
	var c: Dictionary = party[actor_i]
	if not _can_cast(c):
		return

	match c["id"]:
		"stun":
			grana -= c["cost"]
			stunned = true
			_log("%s: OBJEÇÃO! Inimigo perde o próximo turno." % c["name"])
		"heal":
			grana -= c["cost"]
			for m in party:
				if m["hp"] > 0:
					m["hp"] = mini(m["hp"] + HEAL_AMOUNT, m["max_hp"])
			_log("%s serve café: todos curam %d HP." % [c["name"], HEAL_AMOUNT])
		"fake":
			grana -= c["cost"]
			_damage_enemy(12)
			_log("%s espalha Fake News: inimigo se acerta (12)." % c["name"])
		"allin":
			var spent := grana
			grana = 0
			var d := 4 * spent
			_damage_enemy(d)
			_log("%s vai ALL-IN com %d Grana: %d de dano!" % [c["name"], spent, d])
		"hotfix":
			grana -= c["cost"]
			for i in 3:
				_damage_enemy(c["dmg"])
			_log("%s faz Hotfix: 3 hits de %d." % [c["name"], c["dmg"]])
		"mess":
			grana -= c["cost"]
			_damage_enemy(8)
			var msg := "%s causa Baguncinha: 8 de dano." % c["name"]
			if randf() < 0.2:
				var t := _random_alive()
				_hurt(t, 6)
				msg += " Acertou %s sem querer (6)!" % party[t]["name"]
			_log(msg)
	_finish_action()


func _can_cast(c: Dictionary) -> bool:
	if c["id"] == "allin":
		return grana >= 1
	return grana >= c["cost"]


# =====================================================
#  HELPERS
# =====================================================
func _damage_enemy(amount: int) -> void:
	enemy_hp = maxi(0, enemy_hp - amount)
	_flash(enemy_rect)


func _hurt(idx: int, amount: int) -> void:
	party[idx]["hp"] = maxi(0, party[idx]["hp"] - amount)
	_flash(party_ui[idx]["rect"])
	_refresh()


func _next_alive(from: int) -> int:
	for i in range(from + 1, party.size()):
		if party[i]["hp"] > 0:
			return i
	return -1


func _alive_count() -> int:
	var n := 0
	for c in party:
		if c["hp"] > 0:
			n += 1
	return n


func _random_alive() -> int:
	var alive: Array[int] = []
	for i in party.size():
		if party[i]["hp"] > 0:
			alive.append(i)
	return alive[randi() % alive.size()]


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _flash(node: CanvasItem) -> void:
	node.modulate = Color(3, 3, 3)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.25)


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 4:
		log_lines.pop_front()
	if log_label:
		log_label.text = "\n".join(log_lines)


# =====================================================
#  UI
# =====================================================
func _refresh() -> void:
	if party_ui.is_empty():
		return
	for i in party.size():
		var c: Dictionary = party[i]
		var ui: Dictionary = party_ui[i]
		ui["rect"].color = c["color"] if c["hp"] > 0 else Color(0.25, 0.25, 0.25)
		var mark := "▶ " if (state == State.PLAYER_TURN and i == actor_i) else "   "
		ui["label"].text = "%s%s\n   HP %d/%d" % [mark, c["name"], c["hp"], c["max_hp"]]

	enemy_label.text = "%s\nHP %d/%d" % [enemy["name"], enemy_hp, enemy["hp"]]
	grana_label.text = "GRANA  " + "●".repeat(grana) + "○".repeat(GameData.MAX_GRANA - grana)

	if state == State.WIN or state == State.LOSE:
		intent_label.text = ""
	elif stunned:
		intent_label.text = "Inimigo atordoado: perde o turno"
	else:
		var info := _attack_info(pattern[pattern_i % pattern.size()])
		var times: String = "2x " if info["hits"] > 1 else ""
		intent_label.text = "Próximo golpe: %s (%s%d)" % [info["label"], times, info["dmg"]]

	var my_turn := state == State.PLAYER_TURN
	btn_attack.disabled = not my_turn
	if my_turn:
		var c: Dictionary = party[actor_i]
		actor_label.text = "Vez de: %s" % c["name"]
		var cost_txt := "TUDO, mín. 1" if c["id"] == "allin" else "custo %d" % c["cost"]
		btn_special.text = "%s (%s)" % [c["sp"], cost_txt]
		btn_special.disabled = not _can_cast(c)
	else:
		actor_label.text = ""
		btn_special.disabled = true


func _build_party_ui() -> void:
	for i in party.size():
		var y := 80 + i * 120
		var r := _make_rect(Vector2(100, y), Vector2(80, 80), Color.WHITE)
		var l := _make_label(Vector2(200, y + 10), 22)
		party_ui.append({"rect": r, "label": l})


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b1b2f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	enemy_rect = _make_rect(Vector2(780, 120), Vector2(220, 220), Color.WHITE)
	enemy_label = _make_label(Vector2(780, 350), 24)
	intent_label = _make_label(Vector2(640, 30), 24)
	intent_label.modulate = Color("ffcc66")

	grana_label = _make_label(Vector2(100, 20), 28)
	grana_label.modulate = Color("f1c40f")

	actor_label = _make_label(Vector2(100, 440), 24)
	btn_attack = _make_button(Vector2(100, 480), Vector2(260, 50), "Atacar (+1 Grana)")
	btn_attack.pressed.connect(_on_attack)
	btn_special = _make_button(Vector2(380, 480), Vector2(360, 50), "Especial")
	btn_special.pressed.connect(_on_special)

	log_label = _make_label(Vector2(100, 550), 18)

	result_label = _make_label(Vector2(470, 200), 56)
	result_label.visible = false
	btn_continue = _make_button(Vector2(440, 300), Vector2(260, 60), "Continuar")
	btn_continue.visible = false
	btn_continue.pressed.connect(_on_continue)


func _make_rect(pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _make_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _make_button(pos: Vector2, sz: Vector2, text: String) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	add_child(b)
	return b
