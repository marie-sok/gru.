FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q clean package

FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build --chown=10001:10001 /workspace/target/gru-1.0.0.jar /app/gru.jar
ENV PORT=8081
EXPOSE 8081
USER 10001:10001
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75.0","-jar","/app/gru.jar"]
