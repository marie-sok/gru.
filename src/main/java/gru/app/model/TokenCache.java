package gru.app.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.redis.core.RedisHash;

@RedisHash("token_cache")
public class TokenCache {

    @Id
    private String id;
}