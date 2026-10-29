class_name WolfControlText
extends RefCounted
## Presentation-only control copy. Original language tables and story flags stay
## unchanged; keyboard, mouse and HUD instructions describe the actual bindings.
static var replacements: Dictionary={}
static var spaces: RegEx
static func adapt(text: String) -> String:
	if text.is_empty():return text
	if spaces==null:
		spaces=RegEx.new();spaces.compile("\\s+")
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/texts.json"))
		var ru: Dictionary={
			60:"Проход ведет на север в дикие места.\\n\\nW — вперед. A / D — поворот. S — разворот. Также работают клавиши со стрелками.\\n\\nСледи за картой справа вверху. Enter или Пробел закрывает окно с текстом.",
			61:"Какие-то монстры убили этого мужика. Возьму-ка его нож.\\n\\nВыбирай предмет мышью на нижней панели или переключай Q / E. Enter или Пробел использует выбранный предмет, если это возможно.",
			62:"На севере виднеется огонь. Нажми M или кнопку «Карта», чтобы увидеть свое положение на большой карте. Неисследованные места — в темноте.",
			72:"Движение занимает один час и тратит Выносливость, особенно ночью. Еда и отдых восстанавливают ее. После отдыха игра сохраняется.\\n\\nНажми «Спать» на нижней панели или R, чтобы отдохнуть.\\n\\nJ или кнопка «Журнал» открывает текущие задачи.",
			231:"Повреждения от оружия и сила врагов показываются точками. Повреждения зависят от места и оружия. Для атаки нажми Enter или Пробел.",
			34:"Останови превращение Жанет Кейн в оборотня: запри три тотема вендиго в серебряной шахте.\\n\\nПередвижение занимает час и расходует Выносливость. Еда и отдых восстанавливают ее. Урон оружия зависит от времени и места.\\n\\nWASD / стрелки — движение и поворот\\nQ / E или нижняя панель — выбор предмета\\nEnter / Пробел — действие, закрыть текст\\nM — карта    J — журнал    R — спать\\nEsc — меню / назад\\nF2 — оригинальный или широкий вид\\nF5 — сохранить    F9 — загрузить"}
		var en: Dictionary={
			60:"The pass leads north to wilderness.\\n\\nW / Up: move forward. A / D or Left / Right: turn. S / Down: turn around.\\n\\nWatch the map at the top right. Enter or Space closes text windows.",
			61:"Some beast killed this man. I am taking his knife.\\n\\nClick an item on the bottom bar or switch with Q / E. Enter or Space uses the selected item when possible.",
			62:"There is a fire to the north. Press M or click Map to see your position on the large map. Unexplored areas are dark.",
			72:"Moving takes one hour and costs Stamina, especially at night. Food and rest restore it. Resting saves the game.\\n\\nClick Rest on the bottom bar or press R to rest.\\n\\nPress J or click Journal to see your tasks.",
			231:"Weapon damage and enemy strength are shown as dots. Damage varies by time and place. Press Enter or Space to attack.",
			34:"Stop Janet Cain from becoming a werewolf by enclosing three Wendigo totems inside a silver mine.\\n\\nMoving takes an hour and uses Stamina. Food and rest restore it. Weapon damage varies by time and place.\\n\\nWASD / arrows: move and turn\\nQ / E or bottom bar: select an item\\nEnter / Space: act, close text\\nM: map    J: journal    R: rest\\nEsc: menu / back\\nF2: original / wide view\\nF5: save    F9: load"}
		for language: String in ["Русский","English"]:
			var updates: Dictionary=ru if language=="Русский" else en
			for id: int in updates:replacements[spaces.sub(str(catalog[language][id])," ",true).strip_edges()]=str(updates[id]).replace("\\n","\n")
	var normalized: String=spaces.sub(text," ",true).strip_edges()
	for original: String in replacements:
		if normalized.contains(original):return normalized.replace(original,replacements[original])
	return text
