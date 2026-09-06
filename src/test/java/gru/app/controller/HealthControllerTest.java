package gru.app.controller;

import com.mongodb.client.MongoDatabase;
import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class HealthControllerTest {

    @Test
    void livenessDoesNotTouchDatabase() {
        MongoTemplate template = mock(MongoTemplate.class);

        Map<String, Object> response = new HealthController(template, "8081").health();

        assertEquals("ok", response.get("status"));
        assertEquals("not-checked", response.get("database"));
        assertEquals("8081", response.get("port"));
        assertEquals("gru.app.GruApplication", response.get("application"));
    }

    @Test
    void readinessReportsHealthyDatabase() {
        MongoTemplate template = mock(MongoTemplate.class);
        MongoDatabase database = mock(MongoDatabase.class);
        when(template.getDb()).thenReturn(database);
        when(database.runCommand(any(Document.class))).thenReturn(new Document("ok", 1));

        ResponseEntity<Map<String, Object>> response =
                new HealthController(template, "8081").ready();

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("ok", response.getBody().get("status"));
        assertEquals("ok", response.getBody().get("database"));
    }

    @Test
    void readinessReportsDegradedStateWithoutCrashingWhenDatabaseIsDown() {
        MongoTemplate template = mock(MongoTemplate.class);
        when(template.getDb()).thenThrow(new IllegalStateException("database unavailable"));

        ResponseEntity<Map<String, Object>> response =
                new HealthController(template, "8081").ready();

        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, response.getStatusCode());
        assertEquals("degraded", response.getBody().get("status"));
        assertEquals("unavailable", response.getBody().get("database"));
    }
}
