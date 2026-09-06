package gru.app.config;

import org.springframework.boot.autoconfigure.mongo.MongoClientSettingsBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.TimeUnit;

@Configuration
public class MongoTimeoutConfig {

    private static final long SERVER_SELECTION_TIMEOUT_SECONDS = 5L;
    private static final long CONNECT_TIMEOUT_SECONDS = 5L;
    private static final long READ_TIMEOUT_SECONDS = 10L;

    @Bean
    MongoClientSettingsBuilderCustomizer gruMongoTimeouts() {
        return builder -> {
            builder.applyToClusterSettings(settings ->
                    settings.serverSelectionTimeout(
                            SERVER_SELECTION_TIMEOUT_SECONDS,
                            TimeUnit.SECONDS
                    )
            );

            builder.applyToSocketSettings(settings -> {
                settings.connectTimeout(
                        CONNECT_TIMEOUT_SECONDS,
                        TimeUnit.SECONDS
                );
                settings.readTimeout(
                        READ_TIMEOUT_SECONDS,
                        TimeUnit.SECONDS
                );
            });
        };
    }
}
