package gru.app.controller;

import org.bson.Document;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

@RestController
public class HealthController {

    private static final long DATABASE_READY_TIMEOUT_MILLIS = 3_000L;

    private final MongoTemplate mongoTemplate;
    private final String port;
    private final ExecutorService readinessExecutor;

    public HealthController(
            MongoTemplate mongoTemplate,
            @Value("${server.port:8081}") String port
    ) {
        this.mongoTemplate = mongoTemplate;
        this.port = port;
        this.readinessExecutor = Executors.newSingleThreadExecutor(new DaemonThreadFactory());
    }

    /**
     * Render and external uptime checks must never wait for MongoDB.
     * If Spring can serve this route, the process is alive and HTTP routing works.
     */
    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> response = baseResponse();
        response.put("status", "ok");
        response.put("database", "not-checked");
        return response;
    }

    /**
     * Release readiness check. MongoDB is required for normal messenger operation,
     * but a broken database must not make the endpoint hang for 30+ seconds.
     */
    @GetMapping("/ready")
    public ResponseEntity<Map<String, Object>> ready() {
        Future<Boolean> ping = readinessExecutor.submit(databasePing());

        boolean databaseReady;
        String detail;

        try {
            databaseReady = ping.get(DATABASE_READY_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS);
            detail = databaseReady ? "ok" : "unavailable";
        } catch (TimeoutException error) {
            ping.cancel(true);
            databaseReady = false;
            detail = "timeout";
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            ping.cancel(true);
            databaseReady = false;
            detail = "interrupted";
        } catch (ExecutionException error) {
            databaseReady = false;
            detail = "unavailable";
        }

        Map<String, Object> response = baseResponse();
        response.put("status", databaseReady ? "ok" : "degraded");
        response.put("database", detail);

        return ResponseEntity
                .status(databaseReady ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
                .body(response);
    }

    private Callable<Boolean> databasePing() {
        return () -> {
            try {
                mongoTemplate.getDb().runCommand(new Document("ping", 1));
                return true;
            } catch (RuntimeException error) {
                return false;
            }
        };
    }

    private Map<String, Object> baseResponse() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("service", "gru-backend");
        response.put("application", GruApplicationName.VALUE);
        response.put("port", port);
        return response;
    }

    private static final class DaemonThreadFactory implements ThreadFactory {
        @Override
        public Thread newThread(Runnable runnable) {
            Thread thread = new Thread(runnable, "gru-readiness-mongo-ping");
            thread.setDaemon(true);
            return thread;
        }
    }

    private static final class GruApplicationName {
        private static final String VALUE = "gru.app.GruApplication";
    }
}
