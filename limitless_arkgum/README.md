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
    │   ├── Networking/         LimitlessClient, LimitlessAPIError, APIKeyProvider
    │   ├── Storage/            LifelogStore, GRDBLifelogStore, SyncState
    │   ├── Sync/               SyncManager, SyncBackend, HTTPSyncBackend
    │   └── Audio/              AudioStore, FileAudioStore, AudioService
    └── Tests/LimitlessKitTests/

LimitlessApp/                   iOS-приложение (SwiftUI) — собирается в Xcode
├── LimitlessApp.swift          @main точка входа
├── AppEnvironment.swift        composition root (стор + клиент + синхра)
├── ViewModels/                 LifelogListViewModel
├── Views/                      список, деталь (таймлайн спикеров), настройки
├── Security/                   KeychainAPIKeyProvider (ключ только в Keychain)
├── Support/                    форматирование дат/длительностей
├── Info.plist
└── README-Xcode.md             как собрать проект в Xcode

backend/                        Spring Boot приёмник (Maven, Java 17)
├── pom.xml
├── src/main/java/ai/limitless/arkgum/
│   ├── lifelog/                Entity, Repository, Controller (bulk upsert), DTO
│   └── security/               SyncTokenFilter (X-Sync-Token)
├── src/main/resources/         application.yml (H2 dev / Postgres prod)
├── src/test/java/…             LifelogControllerTest
└── README.md
```

Дальше (по `PLAN.md`) добавляются слои `Storage/` (GRDB), `Sync/` (SyncManager) и iOS-таргет
`LimitlessApp` (SwiftUI).

## Статус

- [x] Этап 0 — каркас, план.
- [x] Этап 1 — ядро API-клиента: модели, `LimitlessClient` (пагинация по курсору, backoff на 429,
      толерантное декодирование дат), unit-тесты декодинга.
- [x] Этап 2 — хранилище: `LifelogStore` (протокол) + `GRDBLifelogStore` (SQLite/WAL, миграция,
      upsert-by-newer-updatedAt, флаг `synced`, sync-bookmark).
- [x] Этап 3 — `SyncManager` (actor): инкрементальная дельта-синхра `start=lastSyncTime`,
      постраничный upsert, outbox на бэкенд; интеграционные тесты через `URLProtocol`-мок.
- [x] Этап 4 — iOS UI (SwiftUI): список (pull-to-refresh, sync при `scenePhase`), деталь с
      таймлайном спикеров, экран настроек. Сборка проекта — см. `LimitlessApp/README-Xcode.md`.
- [x] Этап 5 — Keychain для API-ключа (`KeychainAPIKeyProvider`).
- [x] Этап 6 — Spring Boot приёмник (`backend/`) + клиент `HTTPSyncBackend`, настройки бэкенда
      в приложении, outbox уходит на сервер (bulk-upsert по `id`, токен в `X-Sync-Token`).
- [x] Этап 7 — аудио: `downloadAudio` (≤2ч), `FileAudioStore`, `AudioService`; в приложении —
      загрузка + экспорт `.ogg` (`ShareLink`) + очистка кэша.
      ⚠️ iOS не играет Ogg Opus нативно — встроенный плеер это follow-up (Opus-декодер или
      серверная транскодировка). См. `PLAN.md`.

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
