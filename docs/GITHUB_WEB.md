# GitHub и Web

Закрытый репозиторий: [PilotOfAsuka/wolf-moon-remastered](https://github.com/PilotOfAsuka/wolf-moon-remastered). Ветка main отправлена. Публичная Pages пока не включена; ожидается уточнение условия исходного ТЗ о публикации оригинальных ресурсов.

Локальная Web-сборка проверена в браузере: меню → новая игра → вступление → игровой мир → движение → F2 → сохранение → перезагрузка страницы → F9. Ошибок в консоли нет.

В репозиторий входит Godot-проект и необходимые ему ресурсы; JAR, декомпиляция, research, кэши и локальные сборки исключены `.gitignore`.

`Build Godot Web` собирает проект при push в main, скачивая только официальный Godot 4.7.2 и необходимые Web-шаблоны. Готовый `wolf-moon-web` можно скачать из artifacts GitHub Actions. Сторонние actions установки Godot не используются.

`Publish Web to GitHub Pages` — отдельный ручной workflow. Для публикации нужно выбрать Settings → Pages → Source: GitHub Actions и запустить его. До разрешения публикации ресурсов workflow намеренно не запускается автоматически. Удаление самого JAR не удаляет права на изображения и тексты внутри готового PCK.

Web экспорт использует один поток и WebGL 2, поэтому на GitHub Pages не нужны специальные COOP/COEP headers. Официальная документация: [Godot Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

Локальный просмотр после экспорта:

```sh
python3 -m http.server 8765 --directory build/web
```

Открыть `http://localhost:8765/`. Исходный JAR для запуска не нужен. Сохранения браузера находятся в IndexedDB этого origin; приватный режим/запрет хранения могут лишить их долговременного сохранения.
