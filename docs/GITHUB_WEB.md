# GitHub и Web

[Репозиторий](https://github.com/PilotOfAsuka/wolfmoon-remastered) · [Играть в браузере](https://pilotofasuka.github.io/wolfmoon-remastered/)

- **godot** — основная ветка с исходным Godot-проектом.
- **web-build** — готовый экспорт: index.html, JavaScript, WebAssembly и пакет игры в корне ветки.
- GitHub Pages: **Deploy from a branch → web-build → / (root)**. Pages обновляется после отправки новой Web-сборки в эту ветку.

JAR, декомпиляция, research и кэши не публикуются. Godot 4.7.2 экспортирует игру в single-thread WebGL 2, поэтому специальные COOP/COEP headers не нужны. Сохранения хранятся в браузере для адреса сайта.

## Для разработчиков

1. Открыть game/project.godot в Godot 4.7.2 и выполнить экспорт Web.
2. Готовые файлы из build/web перенести в рабочую копию ветки web-build. Локальная рабочая копия сборки — build/web-build; исходная ветка godot остаётся отдельной.
3. Отправить коммит web-build. Игроки открывают ссылку Pages; установка и инструменты разработки им не нужны.

Workflow Build Godot Web оставлен для необязательной ручной проверки. Первая попытка автоматической сборки не стартовала: GitHub сообщил, что Actions аккаунта заблокирован из-за billing issue. Публикация переведена на готовую ветку по предложению пользователя; её фактический результат нужно подтвердить на сайте Pages.
