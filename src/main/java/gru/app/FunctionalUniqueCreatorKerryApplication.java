package gru.app;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

@EnableMongoRepositories(basePackages = "gru.app.repository")
@SpringBootApplication
public class FunctionalUniqueCreatorKerryApplication {

    public static void main(String[] args) {
        SpringApplication.run(
                FunctionalUniqueCreatorKerryApplication.class,
                args
        );
    }
}
