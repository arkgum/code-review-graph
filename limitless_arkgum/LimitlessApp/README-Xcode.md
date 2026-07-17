# Сборка iOS-приложения в Xcode

`.xcodeproj` намеренно не закоммичен (его удобнее генерировать в Xcode на macOS, а бинарный
pbxproj плохо ревьюится). Ниже — как за пару минут собрать приложение из этих исходников.

## Шаги

1. **Xcode → File → New → Project → iOS → App.**
   - Product Name: `LimitlessApp`
   - Interface: **SwiftUI**, Language: **Swift**
   - Bundle Identifier: например `ai.limitless.arkgum` (должен совпадать с `service` в
     `KeychainAPIKeyProvider`, иначе просто держи их согласованными)
   - Minimum Deployments: **iOS 16.0**

2. **Удали** сгенерённые Xcode `ContentView.swift` и `<Name>App.swift` — вместо них используем
   файлы из этой папки.

3. **Добавь исходники**: перетащи в проект содержимое `LimitlessApp/`
   (`LimitlessApp.swift`, `AppEnvironment.swift`, `ViewModels/`, `Views/`, `Security/`,
   `Support/`). Отметь «Copy items if needed» и таргет приложения.

4. **Подключи ядро `LimitlessKit`** (локальный Swift Package):
   - File → Add Package Dependencies → **Add Local…** → выбери папку `../LimitlessKit`.
   - В таргете приложения → General → Frameworks, Libraries → добавь `LimitlessKit`.
   - Это подтянет и транзитивную зависимость **GRDB.swift**.

5. **Info.plist**: используй приложенный `Info.plist` или перенеси из него ключи
   (`UILaunchScreen`, ориентации). Keychain на симуляторе/устройстве работает без доп.
   entitlements для generic password.

6. **Собери и запусти** (⌘R). При первом старте открой ⚙️ → вставь API-ключ из developer-настроек
   Limitless → список синхронизируется.

## Проверка ядра без Xcode-приложения

```bash
cd ../LimitlessKit
swift build
swift test
```

## Замечания

- API-ключ хранится **только в Keychain** (`KeychainAPIKeyProvider`), не в UserDefaults и не в коде.
- Бэкенд (Spring Boot) пока не подключён — синхра тянет данные в локальную SQLite. Подключение
  outbox к бэкенду — этап 6 (реализация `SyncBackend` + сборка в `AppEnvironment`).
