# GRU Messenger

Полноценный локальный backend и клиент GRU Messenger. Backend запускается на Java/Spring Boot, принимает REST-запросы и realtime-соединения STOMP/WebSocket. Проект рассчитан на запуск с IntelliJ IDEA, Xcode/iOS и Flutter Web.

## Состав проекта

```text
src/main/java/          Java backend
src/main/resources/     конфигурация Spring Boot
src/test/java/           backend-тесты
uploads/                локальное хранилище медиафайлов
pom.xml                 Maven-конфигурация
Dockerfile              локальный production-образ
docker-compose.yml      локальный запуск сервисов
pubspec.yaml             Flutter-клиент, если используется
web/                    Flutter Web-ресурсы
```

## Требования

- macOS или Linux;
- JDK 21;
- Maven 3.9 или новее;
- IntelliJ IDEA;
- Docker Desktop — только для запуска через Docker;
- Xcode — только для iOS-клиента;
- Flutter SDK — только для Flutter-клиента.

Проверка инструментов:

```bash
java -version
mvn -version
```

## Запуск из IntelliJ IDEA

1. Открой корневую папку проекта, где находятся `pom.xml` и `src`.
2. Дождись загрузки Maven-проекта.
3. Установи Project SDK: **JDK 21**.
4. Открой класс `GruApplication` в `src/main/java`.
5. Нажми зелёную кнопку запуска рядом с методом `main`.

В IntelliJ можно также открыть Maven → Lifecycle и выполнить:

```text
clean → test → package
```

## Запуск из Terminal

Из корня backend-проекта:

```bash
mvn clean test
mvn spring-boot:run
```

После успешного запуска backend доступен на:

```text
http://127.0.0.1:8081
```

Для телефона в той же Wi‑Fi сети используй IP-адрес Mac:

```bash
ipconfig getifaddr en0
```

Например:

```text
http://192.168.31.61:8081
```

Backend должен слушать все сетевые интерфейсы (`0.0.0.0`), чтобы iPhone мог подключиться по локальному адресу Mac.

## Проверка запуска

```bash
curl -i http://127.0.0.1:8081/health
```

Ожидаемый ответ — `HTTP/1.1 200` и JSON со статусом сервиса.

Проверка по адресу Mac:

```bash
MAC_IP="$(ipconfig getifaddr en0)"
curl -i "http://${MAC_IP}:8081/health"
```

## REST API

Все защищённые запросы передают заголовок:

```http
Authorization: Bearer <JWT>
```

### Авторизация

```text
POST /auth/register
POST /auth/login
```

Пример регистрации:

```bash
curl -X POST http://127.0.0.1:8081/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+79990000000","nickname":"marie.sok","password":"change-me"}'
```

### Пользователи и контакты

```text
GET /users/search?nickname=<query>
GET /presence
```

### Чаты и сообщения

```text
GET  /chats
POST /chats
GET  /chats/{chatId}/messages
POST /chats/{chatId}/read
POST /messages
GET  /messages/unread-counts
```

### Медиа

```text
POST /messages/photo
POST /messages/video
POST /messages/video-note
POST /messages/audio
POST /messages/document
GET  /media/{storedName}
```

Файлы сохраняются в каталоге `uploads/`. Ограничения размера задаются в конфигурации Spring Boot.

### Статусы сообщений и реакции

```text
POST   /messages/{messageId}/delivered
POST   /messages/{messageId}/read
POST   /messages/{messageId}/reaction
DELETE /messages/{messageId}/reaction
DELETE /messages/{messageId}
```

Удаление сообщения через `DELETE /messages/{messageId}` помечает сообщение удалённым для участников чата и рассылает обновление realtime.

## WebSocket / STOMP

Адрес соединения:

```text
ws://127.0.0.1:8081/ws
```

Для iPhone замени `127.0.0.1` на IP Mac.

Основные destinations:

```text
/topic/chat/{chatId}
/topic/chat/{chatId}/typing
/topic/presence
/app/typing
```

WebSocket также использует JWT-аутентификацию.

## Подключение iOS-клиента

В iOS-проекте адрес backend должен быть единым для REST и WebSocket.

- iPhone Simulator: `127.0.0.1`;
- физический iPhone: IP-адрес Mac из `ipconfig getifaddr en0`.

После смены адреса:

1. Останови приложение в Xcode.
2. Выполни **Product → Clean Build Folder**.
3. Запусти приложение снова.

Если iPhone не подключается, проверь:

```bash
lsof -nP -iTCP:8081 -sTCP:LISTEN
curl -i "http://$(ipconfig getifaddr en0):8081/health"
```

## Flutter-клиент

Если используется Flutter-часть проекта:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Для web-клиента адрес API должен указывать на тот же backend `8081`.

## Тесты backend

Запуск всех тестов:

```bash
mvn test
```

Полная проверка перед сборкой:

```bash
mvn clean verify
```

Тесты должны проверять как минимум:

- регистрацию и вход;
- отказ при неверных данных;
- авторизацию защищённых маршрутов;
- создание чата;
- отправку и удаление сообщения;
- загрузку медиа;
- права доступа к чужому чату;
- health endpoint.

## Сборка JAR

```bash
mvn clean package
java -jar target/*.jar
```

## Локальный Docker-запуск

При наличии Docker Desktop:

```bash
docker compose up --build
```

Остановка:

```bash
docker compose down
```

Логи:

```bash
docker compose logs -f
```

## Если порт 8081 занят

Проверить процесс:

```bash
lsof -nP -iTCP:8081 -sTCP:LISTEN
```

Если это старый экземпляр backend, останови именно его PID:

```bash
kill <PID>
```

Затем снова запусти:

```bash
mvn spring-boot:run
```

## Типовые ошибки

### `Could not connect to the server` / `Code -1004`

Backend не запущен, указан неправильный IP или порт закрыт. Сначала проверь `/health` через `curl`.

### `HTTP 401`

Запрос не содержит действительный заголовок `Authorization: Bearer <JWT>`. Сначала выполни вход и сохрани токен.

### WebSocket подключается и сразу закрывается

Проверь адрес `/ws`, JWT и доступность порта 8081 с устройства. Для физического iPhone `127.0.0.1` использовать нельзя.

### IntelliJ не видит запуск

Проверь, что открыт именно корень с `pom.xml`, Maven импортирован, а Project SDK установлен на JDK 21.

## Production checklist

- использовать отдельный сервер и постоянный каталог `uploads`;
- задать сильный секрет JWT;
- ограничить доступ к порту firewall-правилами;
- включить HTTPS/WSS через reverse proxy;
- настроить резервное копирование данных и медиа;
- не хранить пароли, токены и секреты в Git;
- перед релизом выполнить `mvn clean verify`.

## Быстрый порядок запуска

```bash
cd /path/to/gru
mvn clean test
mvn spring-boot:run
```

В другом окне:

```bash
curl -i http://127.0.0.1:8081/health
```

Если ответ `200`, можно запускать iOS или Flutter-клиент.
