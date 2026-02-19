package functional.unique.creator.kerry.repository;

import functional.unique.creator.kerry.model.Message;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {
    List<Message> findBySenderPhoneAndReceiverPhoneOrderByTimestampAsc(String sender, String receiver);

    List<Message> findTop50BySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(Long userId1, Long userId2, Long userId21, Long userId11);
}
