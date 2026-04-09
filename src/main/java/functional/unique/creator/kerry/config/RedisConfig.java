package functional.unique.creator.kerry.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;

import java.util.List;

@Configuration
public class RedisConfig {

    @Bean
    public RedisTemplate<String, List<?>> redisTemplate(RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, List<?>> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        return template;
    }
}