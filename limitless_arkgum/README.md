# limitless_arkgum

Личное iOS-приложение поверх **официального Limitless Developer API**: тянет твои lifelog'и
(транскрипты с диаризацией) из облака Limitless, кэширует локально в SQLite и синхронизирует
при открытии. Опционально — выгрузка на собственный Spring Boot бэкенд.

Полный план и этапы — в [`PLAN.md`](./PLAN.md).

## Почему через API, а не BLE

Limitless Pendant — закрытое железо, сырой аудио-поток стороннему приложению по Bluetooth
не отдаётся. Зато есть официальный Developer API (`https://api.limitless.ai/v1`,
заголовок `X-API-KEY`), который отдаёт уже готовые транскрипты и, при желании, аудио в Ogg Opus.
Поэтому реверс BLE и наработки OMI здесь не нужны — строим честного API-клиента.

## Структура

```
limitless_arkgum/
├── PLAN.md                     подробный план и этапы
├── README.md
└── LimitlessKit/               ядро (Swift Package, платформонезависимое, тестируемое)
    ├── Package.swift
    ├── Sources/LimitlessKit/
    │   ├── Models/             Lifelog, ContentNode, LifelogsResponse
    │   └── Networking/         LimitlessClient, LimitlessAPIError, APIKeyProvider
    └── Tests/LimitlessKitTests/
```

Дальше (по `PLAN.md`) добавляются слои `Storage/` (GRDB), `Sync/` (SyncManager) и iOS-таргет
`LimitlessApp` (SwiftUI).

## Статус

- [x] Этап 0 — каркас, план.
- [x] Этап 1 — ядро API-клиента: модели, `LimitlessClient` (пагинация по курсору, backoff на 429,
      толерантное декодирование дат), unit-тесты декодинга.
- [ ] Этап 2 — хранилище (GRDB + миграции).
- [ ] Этап 3 — `SyncManager` (инкрементальная дельта-синхра).
- [ ] Этап 4 — iOS UI (SwiftUI).
- [ ] Этап 5 — Keychain для API-ключа.
- [ ] Этап 6 — Spring Boot приёмник + outbox.
- [ ] Этап 7 — (опц.) аудио.

## Сборка

Ядро — обычный SPM-пакет. На macOS:

```bash
cd LimitlessKit
swift build
swift test
```

iOS-приложение (`LimitlessApp`) собирается в Xcode на macOS — появится на этапе 4.

## Как получить API-ключ

Настройки Developer в аккаунте Limitless → создать API-ключ. В приложении ключ хранится
**только в Keychain** (этап 5), никогда не в коде и не в UserDefaults.
