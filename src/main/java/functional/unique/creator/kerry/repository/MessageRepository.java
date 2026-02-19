package functional.unique.creator.kerry.repository;

import functional.unique.creator.kerry.model.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {

    List<Message> findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(
            Long senderId1, Long receiverId1,
            Long senderId2, Long receiverId2
    );
}
