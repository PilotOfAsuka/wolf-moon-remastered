# Происхождение ресурсов

Все original/sprites извлечены только из переданного JAR собственным `tools/analyze_jar.py`. Проверки сравнивают каждый PNG crop с его исходной областью. Материалы соседнего проекта не использованы.

`research/experiments/pine_105_hd_unused.png` (локальный неиспользуемый эксперимент) — производный HD-ресурс из оригинального `game/assets/sprites/105.png`. Использован встроенный **image_gen** по навыку imagegen, прозрачность сохранена. Исходный файл не заменён. В runtime не используется после изменения задачи на широкий Classic. Итог эксперимента: подробная сосна с исходными пропорциями, тёмной оливковой палитрой и узнаваемым силуэтом.

Финальный prompt:

> Use case: precise-object-edit. Asset type: high resolution alpha-cutout tree sprite for a faithful personal remaster of the 2006 Wolf Moon game. Input image 1 is the ORIGINAL EDIT TARGET sprite, a very narrow irregular dark olive conifer seen straight on. Redraw this exact ONE tree at high resolution, carefully preserving the same proportions, silhouette, branch-tier rhythm, sparse pointed top, dark olive/yellow-green foliage and dark brown trunk. Improve needle and twig detail to a painterly realistic survival-horror game asset, not a new tree species. Full tree including base in frame, centered, front elevation, no perspective ground plane. Soft neutral diffuse lighting so it can be lit in the game. Truly transparent background, preserve fine transparent gaps between foliage. Do not add any other trees, scenery, cast ground shadow, rocks, text, logos, border, sky or glow.

MIDI cf..cj преобразованы `tools/RenderMidi.java` через штатный Gervill в WAV. Это исходные композиции с современным синтезатором, а не восстановление конкретного телефонного soundfont.

`game/assets/fonts` — локально растеризованные Arial glyphs для MIDP bridge. Font API в Java ME зависел от телефона; эти метрики ещё не сопоставлены с конкретным OEM-устройством.

CFR 0.152: [официальный источник](https://www.benf.org/other/cfr/). Godot: [официальная страница 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/). Ранний Scale2x shader остаётся как необязательный технический fallback, [описание алгоритма](https://www.scale2x.it/algorithm). Финальное широкоформатное представление использует повтор исходного display list, а не Scale2x или 3D.
