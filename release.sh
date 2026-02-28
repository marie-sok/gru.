#!/bin/bash

# ---------------------------
# release.sh
# ---------------------------

# Путь к проекту
PROJECT_DIR="/Users/mariamorozova/Downloads/functional-unique-creator-kerry"

# Порт, на котором будет запускаться приложение
PORT=8081

echo "Сборка проекта..."
cd "$PROJECT_DIR" || exit 1

# Сборка проекта
mvn clean package -DskipTests

# Проверка JAR
JAR_FILE="$PROJECT_DIR/target/kerry-0.0.1-SNAPSHOT.jar"
if [ ! -f "$JAR_FILE" ]; then
    echo "Ошибка: JAR не найден!"
    exit 1
fi

echo "JAR успешно создан: $JAR_FILE"

# Завершение активных процессов
PID=$(lsof -ti tcp:"$PORT")
if [ -n "$PID" ]; then
    echo "Завершаем старый процесс на порту $PORT (PID: $PID)"
    kill -9 "$PID"
fi

# Запуск Spring Boot
echo "Запуск приложения на порту $PORT..."
nohup java -jar "$JAR_FILE" --server.port="$PORT" > "$PROJECT_DIR/nohup.log" 2>&1 &

# Загрузка запуска
sleep 5

# Проверяека запуска приложения
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:"$PORT")
if [ "$HTTP_STATUS" != "200" ] && [ "$HTTP_STATUS" != "401" ]; then
    echo "Ошибка: приложение не отвечает. HTTP статус: $HTTP_STATUS"
    exit 1
fi

# Запуск ngrok
echo "Запуск ngrok туннеля..."
ngrok http "$PORT" --log=stdout &
sleep 3

echo "Приложение запущено и доступно через ngrok!"
echo "Проверяйте URL на экране ngrok или в http://127.0.0.1:4040"
