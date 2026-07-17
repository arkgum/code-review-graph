# limitless_arkgum — план разработки

iOS-приложение (только iOS, для личного использования) поверх **официального Limitless Developer API**.
Локальный кэш в SQLite + инкрементальная синхронизация при открытии + опциональная выгрузка на свой Spring Boot бэкенд.

> Реверс BLE-протокола кулона **не используется**. Источник данных — облако Limitless через
> `https://api.limitless.ai/v1`, авторизация заголовком `X-API-KEY`. Транскрипты приходят уже
> готовыми (с диаризацией), поэтому whisper.cpp и BLE-слой из первоначального плана убраны.

---

## 1. Архитектура

```
Limitless Cloud API  ──GET /v1/lifelogs?start=…&cursor=…──▶  iOS-приложение (Swift)
     (X-API-KEY)                                              ├── LimitlessKit (SPM, ядро)
                                                              │     ├── Networking (LimitlessClient)
                                                              │     ├── Models    (Lifelog, ContentNode)
                                                              │     ├── Storage   (SQLite через GRDB)
                                                              │     └── Sync      (SyncManager, outbox)
                                                              └── LimitlessApp (SwiftUI UI)
                                                                        │
                                                          push только новое (outbox)
                                                                        ▼
                                                              Spring Boot backend (позже)
```

**Принцип разделения:** вся логика (сеть, модели, синхра, стор) живёт в чистом Swift-package
`LimitlessKit` — платформонезависимом и тестируемом. UI-слой (`LimitlessApp`, SwiftUI) только
отображает данные и дёргает `SyncManager`.

---

## 2. Слои и ответственность

| Слой | Файлы | Ответственность |
|------|-------|-----------------|
| **Models** | `Lifelog`, `ContentNode`, `LifelogsResponse` | Codable-модели ответа API |
| **Networking** | `LimitlessClient`, `LimitlessAPIError`, `APIKeyProvider` | HTTP, заголовок `X-API-KEY`, пагинация по курсору, ретраи |
| **Storage** | `LifelogStore` (протокол), `GRDBLifelogStore`, `SyncState` | upsert по `id`, чтение/запись `lastSyncTime`, флаг `synced` |
| **Sync** | `SyncManager` | инкрементальная дельта-синхра, outbox для бэкенда |
| **Security** | `KeychainAPIKeyProvider` | API-ключ только в Keychain, никогда в коде/UserDefaults |
| **UI** | `LifelogListView`, `LifelogDetailView`, `SettingsView` | список, деталь с таймлайном спикеров, ввод ключа |

---

## 3. Логика синхронизации (при открытии приложения)

`ScenePhase == .active` / `.onAppear` запускает `SyncManager.sync()`:

1. Прочитать `lastSyncTime` из `SyncState` (nil при первом запуске).
2. `GET /v1/lifelogs?start=<lastSyncTime>&direction=asc&limit=…`, идти по `meta.lifelogs.nextCursor`
   пока не `null`.
3. Для каждого lifelog — **upsert по `id`** (обновляем изменённые по `updatedAt`).
4. Новые/изменённые пометить `synced = false`.
5. `lastSyncTime = max(updatedAt)` полученных записей.
6. (Опц.) outbox: отправить `synced = false` на Spring Boot, при 2xx пометить `synced = true`.

Свойства: идемпотентно, переживает обрыв сети (курсор+lastSyncTime персистятся), тянет только дельту.

---

## 4. Модель данных (SQLite)

**lifelog**
| колонка | тип | примечание |
|---------|-----|-----------|
| id | TEXT PK | из API |
| title | TEXT | |
| markdown | TEXT? | |
| start_time | TEXT (ISO-8601) | |
| end_time | TEXT | |
| is_starred | INTEGER | |
| updated_at | TEXT | ключ инкрементальности |
| contents_json | TEXT | сериализованные `contents[]` |
| synced | INTEGER | 0 = ждёт отправки на бэкенд |
| fetched_at | TEXT | когда положили локально |

**sync_state** (одна строка): `last_sync_time`, `last_cursor`.

---

## 5. Безопасность (инварианты)

- API-ключ **только в Keychain** (`KeychainAPIKeyProvider`), не в UserDefaults и не в коде.
- Все сетевые запросы только по HTTPS к `api.limitless.ai`.
- Параметры URL — через `URLComponents`/`queryItems`, без ручной конкатенации.
- Никаких секретов в логах; логировать только статусы/счётчики.
- Уважать rate limit (~180 req/min): последовательная пагинация, backoff на 429.

---

## 6. Этапы (инкременты)

- [x] **0. Каркас + план** — структура папок, `PLAN.md`, `README.md`.
- [x] **1. LimitlessKit ядро** — модели, `LimitlessClient`, ошибки, пагинация.
- [x] **2. Хранилище** — протокол `LifelogStore` + GRDB-реализация, миграции.
- [x] **3. SyncManager** — инкрементальная дельта-синхра + тесты.
- [x] **4. iOS UI (SwiftUI)** — список, деталь с таймлайном спикеров, экран настроек (ввод ключа).
- [x] **5. Keychain** — безопасное хранение ключа (`KeychainAPIKeyProvider`).
- [ ] **6. Spring Boot приёмник** — endpoint + JPA-сущность + outbox-отправка с клиента. ← дальше
- [ ] **7. (Опц.) Аудио** — выгрузка Ogg Opus по диапазону времени, локальное хранение.

---

## 7. Технологии

- **Swift 5.9+**, **iOS 16+** (`ScenePhase`, `NavigationStack`, async/await).
- **SwiftUI** — UI.
- **GRDB.swift** — SQLite (типобезопасно, миграции, наблюдение).
- **URLSession** async/await — сеть (без сторонних HTTP-клиентов).
- **Swift Package Manager** — ядро вынесено в локальный package `LimitlessKit`.

> В этой (Linux/CI) среде Xcode-таргет не собирается — здесь пишем и держим корректный исходник.
> Сборка/запуск — на macOS в Xcode. `LimitlessKit` как чистый SPM-package потенциально собираем и на Linux.
