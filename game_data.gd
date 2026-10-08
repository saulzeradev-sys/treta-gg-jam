class_name GameData
extends RefCounted
## Todos os dados de balanceamento e texto num lugar só. Ajuste números AQUI.

const MAX_GRANA := 5
const PARTY_SIZE := 3

# unlock = índice da fase a partir da qual o personagem pode ser escolhido (0 = desde o início)
static var roster: Array = [
	{"name": "Jones",      "max_hp": 30, "dmg": 4, "color": Color("e0a030"), "sp": "Objeção!",      "cost": 2, "id": "stun",   "unlock": 0},
	{"name": "Metrópoles", "max_hp": 25, "dmg": 3, "color": Color("c0392b"), "sp": "Café Coletivo", "cost": 2, "id": "heal",   "unlock": 0},
	{"name": "Dudu",       "max_hp": 22, "dmg": 3, "color": Color("27ae60"), "sp": "Fake News",     "cost": 3, "id": "fake",   "unlock": 0},
	{"name": "Eder",       "max_hp": 35, "dmg": 5, "color": Color("8e44ad"), "sp": "ALL-IN!",       "cost": 1, "id": "allin",  "unlock": 1},
	{"name": "Iran",       "max_hp": 20, "dmg": 2, "color": Color("2980b9"), "sp": "Hotfix x3",     "cost": 1, "id": "hotfix", "unlock": 1},
	{"name": "Galego",     "max_hp": 28, "dmg": 4, "color": Color("16a085"), "sp": "Baguncinha",    "cost": 2, "id": "mess",   "unlock": 0},
]

# pattern: "w" = fraco | "s" = forte | "d" = duplo (2 golpes fracos em alvos aleatórios)
# phase2 (opcional): padrão novo quando HP <= 50%. Apague a chave para cortar a fase 2 do chefe.
static var enemies: Array = [
	{
		"name": "Admin Estagiário", "chat": "Admin Estagiário",
		"preview": "Você não tem permissão para isso.",
		"hp": 40, "weak": 4, "strong": 9, "pattern": ["w", "w", "s"],
		"color": Color("7f8c8d"),
	},
	{
		"name": "Tio do Zap", "chat": "Tio do Zap (Família)",
		"preview": "[audio 4:12] Bom dia, grupo é família!",
		"hp": 60, "weak": 5, "strong": 12, "pattern": ["w", "s", "w"],
		"color": Color("d35400"),
	},
	{
		"name": "Bot de Golpe", "chat": "Bot de Golpe",
		"preview": "Parabéns! Você ganhou um Pix de volta.",
		"hp": 80, "weak": 6, "strong": 14, "pattern": ["s", "w", "w"],
		"color": Color("f1c40f"),
	},
	{
		"name": "Mãe de Alguém", "chat": "Mãe de Alguém",
		"preview": "Sai da frente do computador.",
		"hp": 100, "weak": 6, "strong": 14, "pattern": ["w", "s", "s"],
		"color": Color("e84393"),
	},
	{
		"name": "O Moderador", "chat": "Moderador",
		"preview": "Este grupo será excluído.",
		"hp": 160, "weak": 6, "strong": 14, "pattern": ["w", "s", "w"],
		"phase2": ["d", "s"],
		"color": Color("636e72"),
	},
]
