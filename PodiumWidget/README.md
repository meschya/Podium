# Podium Widget — экран блокировки

Виджет только для **Lock Screen** (не домашний экран):

- **Прямоугольник под часами** — `.accessoryRectangular`: сверху строка `P1 • Команда • N points` с разделителями-кружками, снизу **фото болида** из тех же ассетов, что в приложении (`rebullracing_bolid`, `mclaren_bolid`, …). Картинки лежат в `PodiumWidget/Assets.xcassets/Bolids` (копия `Podium/Assets.xcassets/Bolids`).
- Дополнительно: узкая строка **.accessoryInline** и круг **.accessoryCircular** (только болид).

### Как добавить на заблокированный экран

1. Заблокируй iPhone → **долгое нажатие** по экрану блокировки → **Настроить** → выбери **Экран блокировки**.
2. **Добавить виджеты** → найди **Podium** → выбери размер **прямоугольный** (под часами).

### Данные из приложения

Через App Group `group.com.EMYM.Podium` (см. основной таргет Podium). Без группы показываются значения по умолчанию.

### Info.plist

В расширении задан `NSExtension` → `com.apple.widgetkit-extension`.
