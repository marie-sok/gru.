# ================= BUILD STAGE =================
FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# ================= RUNTIME =================
FROM eclipse-temurin:17-jre

WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8081

ENTRYPOINT ["java","-jar","app.jar"]