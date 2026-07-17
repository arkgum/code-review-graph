# limitless-backend

Spring Boot приёмник lifelog'ов, которые iOS-приложение выгружает из локального кэша (outbox).

## Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| `POST` | `/api/lifelogs` | Bulk-upsert массива lifelog'ов, идемпотентно по `id` |
| `GET`  | `/api/lifelogs/count` | Кол-во записей (для проверки) |

Все `/api/**` требуют заголовок `X-Sync-Token`, равный серверному `sync.token`.

### Пример

```bash
curl -X POST http://localhost:8080/api/lifelogs \
  -H "X-Sync-Token: $SYNC_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{"id":"log-1","title":"Standup","isStarred":false,
        "updatedAt":"2026-07-17T09:16:00Z","contents":[]}]'
# -> {"received":1,"inserted":1,"updated":0}
```

## Запуск

```bash
cd backend
SYNC_TOKEN=$(openssl rand -hex 16) ./mvnw spring-boot:run   # или mvn, если Maven установлен
```

По умолчанию — in-memory H2 (данные не переживают рестарт). Для продакшена:

```bash
SPRING_PROFILES_ACTIVE=prod \
JDBC_DATABASE_URL=jdbc:postgresql://host:5432/limitless \
JDBC_DATABASE_USERNAME=... JDBC_DATABASE_PASSWORD=... \
SYNC_TOKEN=... java -jar target/limitless-backend-0.1.0.jar
```

## Тесты

```bash
./mvnw test
```

`LifelogControllerTest` проверяет: отказ без токена (401) и идемпотентность upsert по `id`.

## Контракт с клиентом

Тело запроса — JSON-массив в кодировке Swift-модели `Lifelog`: поля `id`, `title`, `markdown`,
`startTime`, `endTime`, `isStarred`, `updatedAt` (ISO-8601), и `contents` (дерево — хранится как
JSON-текст в колонке `contents_json`). Соответствующий клиент — `HTTPSyncBackend` в iOS-приложении.
