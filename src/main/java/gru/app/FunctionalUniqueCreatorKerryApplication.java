package gru.app;

import gru.app.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

@EnableMongoRepositories(basePackages = "gru.app.repository")

@SpringBootApplication
public class FunctionalUniqueCreatorKerryApplication {
    public static void main(String[] args) {
        SpringApplication.run(FunctionalUniqueCreatorKerryApplication.class, args);
    }

    @Bean
    CommandLineRunner testDb(UserRepository userRepository) {
        return args -> {
            System.out.println("Всего пользователей: " + userRepository.count());
        };
    }
}
