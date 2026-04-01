package functional.unique.creator.kerry.repository;

import functional.unique.creator.kerry.model.Message;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {

    List<Message> findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByCreatedAtAsc(
            Long s1, Long r1, Long s2, Long r2
    );
}