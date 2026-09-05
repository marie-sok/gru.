package gru.app.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class HealthController {

    private final MongoTemplate mongoTemplate;
    private final String port;

    public HealthController(
            MongoTemplate mongoTemplate,
            @Value("${server.port:8081}") String port
    ) {
        this.mongoTemplate = mongoTemplate;
        this.port = port;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("service", "gru-backend");
        response.put("application", GruApplicationName.VALUE);
        response.put("port", port);

        try {
            mongoTemplate.getDb().runCommand(new org.bson.Document("ping", 1));
            response.put("status", "ok");
            response.put("database", "ok");
        } catch (RuntimeException error) {
            response.put("status", "degraded");
            response.put("database", "unavailable");
        }

        return response;
    }

    private static final class GruApplicationName {
        private static final String VALUE = "gru.app.GruApplication";
    }
}
