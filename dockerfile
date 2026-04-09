FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

COPY pom.xml .
RUN ./mvnw dependency:go-offline -B || mvn dependency:go-offline -B

COPY src ./src

RUN ./mvnw clean package -DskipTests || mvn clean package -DskipTests

EXPOSE 8081

CMD ["java", "-jar", "target/messenger-backend-1.0.0.jar"]