package gru.app.controller;

import com.mongodb.client.MongoDatabase;
import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.data.mongodb.core.MongoTemplate;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class HealthControllerTest {

    @Test
    void reportsHealthyDatabase() {
        MongoTemplate template = mock(MongoTemplate.class);
        MongoDatabase database = mock(MongoDatabase.class);
        when(template.getDb()).thenReturn(database);
        when(database.runCommand(any(Document.class))).thenReturn(new Document("ok", 1));

        Map<String, Object> response = new HealthController(template, "8081").health();

        assertEquals("ok", response.get("status"));
        assertEquals("ok", response.get("database"));
        assertEquals("8081", response.get("port"));
        assertEquals("gru.app.GruApplication", response.get("application"));
    }

    @Test
    void reportsDegradedStateWithoutCrashingWhenDatabaseIsDown() {
        MongoTemplate template = mock(MongoTemplate.class);
        when(template.getDb()).thenThrow(new IllegalStateException("database unavailable"));

        Map<String, Object> response = new HealthController(template, "8081").health();

        assertEquals("degraded", response.get("status"));
        assertEquals("unavailable", response.get("database"));
    }
}
