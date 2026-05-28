FROM eclipse-temurin:23-jdk

WORKDIR /app

COPY target/app.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]