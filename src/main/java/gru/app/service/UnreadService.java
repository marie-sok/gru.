package gru.app.service;

import gru.app.dto.UnreadCountsResponse;
import gru.app.model.Message;
import lombok.RequiredArgsConstructor;
import org.bson.Document;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.aggregation.AggregationResults;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UnreadService {

    private final MongoTemplate mongoTemplate;

    // MARK: - Get Unread Counts

    public UnreadCountsResponse getUnreadCounts(
            String userId
    ) {

        if (
                userId == null ||
                        userId.isBlank()
        ) {

            return new UnreadCountsResponse(
                    Map.of(),
                    0
            );
        }

        /*
         Считаем только сообщения:

         receiverId == текущий пользователь
         readAt == null

         Исходящие сообщения сюда
         никогда не попадут.
         */

        Aggregation aggregation =
                Aggregation.newAggregation(

                        Aggregation.match(
                                Criteria
                                        .where("receiverId")
                                        .is(userId)
                                        .and("readAt")
                                        .is(null)
                        ),

                        Aggregation.group("chatId")
                                .count()
                                .as("count")
                );

        AggregationResults<Document> results =
                mongoTemplate.aggregate(
                        aggregation,
                        Message.class,
                        Document.class
                );

        Map<String, Long> chats =
                new LinkedHashMap<>();

        long total =
                0;

        for (Document document :
                results.getMappedResults()) {

            Object chatIDValue =
                    document.get("_id");

            Object countValue =
                    document.get("count");

            if (
                    chatIDValue == null ||
                            countValue == null
            ) {

                continue;
            }

            String chatId =
                    chatIDValue.toString();

            if (chatId.isBlank()) {

                continue;
            }

            long count;

            if (countValue instanceof Number number) {

                count =
                        number.longValue();

            } else {

                continue;
            }

            if (count <= 0) {

                continue;
            }

            chats.put(
                    chatId,
                    count
            );

            total +=
                    count;
        }

        return new UnreadCountsResponse(
                chats,
                total
        );
    }
}