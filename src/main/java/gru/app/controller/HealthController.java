package gru.app.controller;

import org.bson.Document;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Locale;
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

    public HealthController(MongoTemplate mongoTemplate, @Value("${server.port:8081}") String port) {
        this.mongoTemplate = mongoTemplate;
        this.port = port;
        this.readinessExecutor = Executors.newSingleThreadExecutor(new DaemonThreadFactory());
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> response = baseResponse();
        response.put("status", "ok");
        response.put("database", "not-checked");
        return response;
    }

    @GetMapping("/ready")
    public ResponseEntity<Map<String, Object>> ready() {
        Future<DatabaseProbe> ping = readinessExecutor.submit(databasePing());
        DatabaseProbe probe;

        try {
            probe = ping.get(DATABASE_READY_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS);
        } catch (TimeoutException error) {
            ping.cancel(true);
            probe = DatabaseProbe.failed("timeout");
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            ping.cancel(true);
            probe = DatabaseProbe.failed("interrupted");
        } catch (ExecutionException error) {
            probe = DatabaseProbe.failed(classifyDatabaseError(error.getCause()));
        }

        Map<String, Object> response = baseResponse();
        response.put("status", probe.ready() ? "ok" : "degraded");
        response.put("database", probe.ready() ? "ok" : "unavailable");
        response.put("databaseReason", probe.reason());

        return ResponseEntity
                .status(probe.ready() ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
                .body(response);
    }

    private Callable<DatabaseProbe> databasePing() {
        return () -> {
            try {
                mongoTemplate.getDb().runCommand(new Document("ping", 1));
                return DatabaseProbe.success();
            } catch (RuntimeException error) {
                return DatabaseProbe.failed(classifyDatabaseError(error));
            }
        };
    }

    private String classifyDatabaseError(Throwable error) {
        Throwable current = error;
        while (current != null) {
            String className = current.getClass().getName().toLowerCase(Locale.ROOT);
            String message = current.getMessage() == null ? "" : current.getMessage().toLowerCase(Locale.ROOT);

            if (message.contains("authentication failed") || message.contains("bad auth")
                    || message.contains("auth failed") || message.contains("code 8000")
                    || className.contains("mongosecurityexception")) {
                return "auth_failed";
            }
            if (className.contains("unknownhostexception") || message.contains("unknown host")
                    || message.contains("querysrv") || message.contains("srv lookup") || message.contains("dns")) {
                return "dns";
            }
            if (className.contains("timeout") || message.contains("timed out") || message.contains("timeout")) {
                return "timeout";
            }
            if (className.contains("mongosocket") || className.contains("connectexception")
                    || message.contains("connection refused") || message.contains("connection reset")
                    || message.contains("network is unreachable")) {
                return "network";
            }
            current = current.getCause();
        }
        return "unknown";
    }

    private Map<String, Object> baseResponse() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("service", "gru-backend");
        response.put("application", GruApplicationName.VALUE);
        response.put("port", port);
        return response;
    }

    private record DatabaseProbe(boolean ready, String reason) {
        private static DatabaseProbe success() {
            return new DatabaseProbe(true, "ok");
        }

        private static DatabaseProbe failed(String reason) {
            return new DatabaseProbe(false, reason);
        }
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
