# GitHub и Web

Репозиторий: [PilotOfAsuka/wolf-moon-remastered](https://github.com/PilotOfAsuka/wolf-moon-remastered).

Адрес игры после первой успешной публикации: [Играть в браузере](https://pilotofasuka.github.io/wolf-moon-remastered/). Ссылка размещена в начале README. Игра распространяется только как Web; установка не нужна.

Пользователь разрешил открыть репозиторий и публиковать готовую игру, отменив прежнее ограничение ТЗ. Сам JAR, декомпиляция, research, локальные сборки и кэши исключены из Git. Репозиторий открыт после подтверждения GitHub Mobile. В Pages выбран источник GitHub Actions; первая публикация готовится.

`Publish Web to GitHub Pages` собирает и публикует игру при push в main или ручном запуске. В Settings → Pages источником должна быть выбрана GitHub Actions. Workflow получает официальный Godot 4.7.2 и Web-шаблон, импортирует проект, экспортирует Web и разворачивает Pages. Артефакт сборки используется автоматически для публикации.

`Build Godot Web` проверяет сборку pull request и доступен для ручной проверки. Отдельная публикация установочных сборок не предусмотрена.

Web использует один поток и WebGL 2, поэтому специальные COOP/COEP headers не нужны. Сохранения находятся в IndexedDB текущего origin.

Для разработчиков: локальный экспорт `Godot --headless --path game --export-release Web`, затем `python3 -m http.server 8765 --directory build/web`. Для запуска готовой игры эти инструменты не нужны.
