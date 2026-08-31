package gru.app.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.security.KeyPair;
import java.security.KeyPairGenerator;

@Configuration
public class JwtKeyConfig {

    @Bean
    public KeyPair keyPair() throws Exception {

        KeyPairGenerator generator =
                KeyPairGenerator.getInstance("EC");

        generator.initialize(256);

        return generator.generateKeyPair();
    }
}