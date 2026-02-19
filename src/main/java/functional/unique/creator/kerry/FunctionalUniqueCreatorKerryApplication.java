package functional.unique.creator.kerry;

import functional.unique.creator.kerry.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

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
