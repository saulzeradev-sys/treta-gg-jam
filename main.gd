extends Control
## Controlador de fluxo: Título -> Lista de conversas -> Seleção de party -> Batalha -> (volta à lista | Final)
## Cena principal: nó raiz Control com este script. Janela padrão 1152x648.

const USE_PARTY_SELECT := true      # false = party fixa (item 3 do plano de corte)
const DEBUG_UNLOCK_ALL := false     # true = libera todas as conversas para testar o chefe
const DEFAULT_PARTY := [0, 1, 5]    # usada quando USE_PARTY_SELECT = false

var cleared := 0                    # fases concluídas (0..5)
var current_fase := 0
var selected_party: Array = []

var holder: Control
var screen: Control
var fader: ColorRect
var pick_btn: Button
var pick_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(self, Vector2.ZERO, Vector2(1152, 648), Color("0b141a"))
	holder = Control.new()
	add_child(holder)
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader = _rect(self, Vector2.ZERO, Vector2(1152, 648), Color(0, 0, 0, 1))
	if DEBUG_UNLOCK_ALL:
		cleared = GameData.enemies.size() - 1
	_go(_build_title)


# =====================================================
#  TRANSIÇÃO (fade out -> troca de tela -> fade in)
# =====================================================
func _go(builder: Callable) -> void:
	fader.mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia cliques durante o fade
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.25)
	await tw.finished
	if screen:
		screen.queue_free()
	screen = Control.new()
	holder.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	builder.call(screen)
	tw = create_tween()
	tw.tween_property(fader, "color:a", 0.0, 0.25)
	await tw.finished
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE


# =====================================================
#  TELA: TÍTULO
# =====================================================
func _build_title(p: Control) -> void:
	_label(p, "GG - GORDOS GAMING", Vector2(260, 190), 64)
	_label(p, "O Último Grupo", Vector2(460, 280), 32, Color("25d366"))
	var b := _button(p, "Jogar", Vector2(450, 400), Vector2(250, 70))
	b.pressed.connect(func() -> void: _go(_build_chat_list))


# =====================================================
#  TELA: LISTA DE CONVERSAS (substitui o mapa)
# =====================================================
func _build_chat_list(p: Control) -> void:
	_rect(p, Vector2.ZERO, Vector2(1152, 90), Color("1f2c34"))
	_label(p, "GG - Gordos Gaming", Vector2(30, 20), 32)
	_label(p, "Conversas salvas: %d/%d" % [cleared, GameData.enemies.size()],
		Vector2(800, 30), 22, Color("25d366"))

	for i in GameData.enemies.size():
		var e: Dictionary = GameData.enemies[i]
		var y := 110 + i * 100
		var b := _button(p, "", Vector2(26, y), Vector2(1100, 90))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(b, Color("1f2c34"), Color("1f2c34"), 110)

		var avatar := _rect(p, Vector2(40, y + 15), Vector2(60, 60), e["color"])
		if i > cleared and not DEBUG_UNLOCK_ALL:
			b.disabled = true
			b.text = "Conversa bloqueada\nVença a conversa anterior para liberar"
			avatar.color = Color("3b4a54")
		else:
			var done := " (concluída)" if i < cleared else ""
			b.text = "%s%s\n%s" % [e["chat"], done, e["preview"]]
			b.pressed.connect(_on_chat_pressed.bind(i))


func _on_chat_pressed(i: int) -> void:
	current_fase = i
	if USE_PARTY_SELECT:
		_go(_build_party_select)
	else:
		selected_party = DEFAULT_PARTY.duplicate()
		_go(_build_battle)


# =====================================================
#  TELA: SELEÇÃO DE PARTY (escolha 3; a ordem de escolha = ordem de ação)
# =====================================================
func _build_party_select(p: Control) -> void:
	selected_party.clear()
	var e: Dictionary = GameData.enemies[current_fase]
	_label(p, "Contra: %s" % e["name"], Vector2(60, 25), 34)
	_label(p, "Escolha 3 personagens (a ordem de escolha é a ordem de ação)", Vector2(60, 75), 20, Color("8696a0"))

	for i in GameData.roster.size():
		var c: Dictionary = GameData.roster[i]
		var x := 60 + (i % 3) * 360
		var y := 130 + (i / 3) * 170
		var b := _button(p, "", Vector2(x, y), Vector2(340, 150))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(b, Color("1f2c34"), Color("1e6b4a"), 110)
		var avatar := _rect(p, Vector2(x + 18, y + 35), Vector2(70, 70), c["color"])
		if c["unlock"] > current_fase:
			b.disabled = true
			avatar.color = Color("3b4a54")
			b.text = "%s\nEntra na fase %d" % [c["name"], c["unlock"] + 1]
		else:
			var cost_txt := "TUDO" if c["id"] == "allin" else str(c["cost"])
			b.text = "%s\nHP %d  Dano %d\n%s (%s)" % [c["name"], c["max_hp"], c["dmg"], c["sp"], cost_txt]
			b.toggled.connect(_on_pick.bind(i, b))

	pick_label = _label(p, "", Vector2(60, 535), 22)
	var back := _button(p, "Voltar", Vector2(560, 520), Vector2(180, 60))
	back.pressed.connect(func() -> void: _go(_build_chat_list))
	pick_btn = _button(p, "Lutar!", Vector2(760, 520), Vector2(300, 60))
	pick_btn.pressed.connect(func() -> void: _go(_build_battle))
	_update_pick()


func _on_pick(on: bool, i: int, btn: Button) -> void:
	if on:
		if selected_party.size() >= GameData.PARTY_SIZE:
			btn.set_pressed_no_signal(false)
			return
		selected_party.append(i)
	else:
		selected_party.erase(i)
	_update_pick()


func _update_pick() -> void:
	pick_label.text = "Escolhidos: %d/%d" % [selected_party.size(), GameData.PARTY_SIZE]
	pick_btn.disabled = selected_party.size() != GameData.PARTY_SIZE


# =====================================================
#  TELA: BATALHA
# =====================================================
func _build_battle(p: Control) -> void:
	var b := Battle.new()
	p.add_child(b)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.finished.connect(_on_battle_finished)
	b.start(selected_party.duplicate(), current_fase)


func _on_battle_finished(won: bool) -> void:
	if won:
		cleared = maxi(cleared, current_fase + 1)
		if cleared >= GameData.enemies.size():
			_go(_build_ending)
			return
	_go(_build_chat_list)   # derrota: volta à lista e a conversa continua liberada


# =====================================================
#  TELA: FINAL (placeholder; o final real entra no passo de diálogo)
# =====================================================
func _build_ending(p: Control) -> void:
	_label(p, "O GRUPO ESTÁ SALVO!", Vector2(300, 220), 56, Color("25d366"))
	_label(p, "(final real e créditos entram no passo de diálogo)", Vector2(300, 310), 22, Color("8696a0"))
	var b := _button(p, "Voltar ao início", Vector2(430, 400), Vector2(300, 70))
	b.pressed.connect(func() -> void:
		cleared = 0
		_go(_build_title))


# =====================================================
#  HELPERS DE UI
# =====================================================
func _rect(p: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)
	return r


func _label(p: Control, text: String, pos: Vector2, fs: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return l


func _button(p: Control, text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 22)
	p.add_child(b)
	return b


func _style_button(b: Button, normal: Color, pressed: Color, margin_left: int) -> void:
	b.add_theme_stylebox_override("normal", _sb(normal, margin_left))
	b.add_theme_stylebox_override("hover", _sb(normal.lightened(0.12), margin_left))
	b.add_theme_stylebox_override("pressed", _sb(pressed, margin_left))
	b.add_theme_stylebox_override("hover_pressed", _sb(pressed.lightened(0.1), margin_left))
	b.add_theme_stylebox_override("disabled", _sb(Color("111b21"), margin_left))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _sb(col: Color, margin_left: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.content_margin_left = margin_left
	s.content_margin_right = 20
	s.set_corner_radius_all(8)
	return s
