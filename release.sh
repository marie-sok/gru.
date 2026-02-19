#!/bin/bash

echo "Сборка проекта..."
mvn clean package -DskipTests

JAR_FILE=$(ls target/*.jar | head -n 1)
if [ ! -f "$JAR_FILE" ]; then
  echo "Ошибка: JAR не найден!"
  exit 1
fi

echo "JAR успешно создан: $JAR_FILE"

echo "Запуск приложения для теста..."
java -jar "$JAR_FILE" &
APP_PID=$!

sleep 10

HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost:8081/actuator/health)

if [ "$HTTP_STATUS" == "200" ]; then
  echo "Приложение успешно стартовало. Готово к релизу!"
else
  echo "Ошибка: приложение не отвечает. HTTP статус: $HTTP_STATUS"
  kill $APP_PID
  exit 1
fi

kill $APP_PID
echo "Тестовое приложение остановлено."

echo "Создание релизного тега..."
git add .
git commit -m "Release version $(date +%Y.%m.%d)"
git tag -a "v$(date +%Y.%m.%d)" -m "Release version $(date +%Y.%m.%d)"
git push origin main --tags

echo "Релиз завершен!"
