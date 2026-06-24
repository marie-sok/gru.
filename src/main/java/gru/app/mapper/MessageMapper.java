package gru.app.mapper;

import gru.app.dto.MessageResponse;
import gru.app.model.Message;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

@Mapper(componentModel = "spring")
public interface MessageMapper {

    @Mapping(
            target = "createdAt",
            source = "createdAt",
            qualifiedByName = "toMillis"
    )
    MessageResponse toResponse(Message<?> message);

    @Named("toMillis")
    static Long toMillis(java.time.Instant instant) {
        return instant == null ? null : instant.toEpochMilli();
    }
}