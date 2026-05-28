package gru.app.mapper;


import gru.app.dto.MessageResponse;
import gru.app.model.Message;

@Mapper(componentModel = "spring")
public interface MessageMapper {

    @Mapping(
            target = "createdAt",
            source = "createdAt",
            qualifiedByName = "toMillis"
    )
    MessageResponse toResponse(Message message);

    @Named("toMillis")
    default Long toMillis(java.time.LocalDateTime time) {
        if (time == null) {
            return null;
        }

        return time
                .atZone(java.time.ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli();
    }
}