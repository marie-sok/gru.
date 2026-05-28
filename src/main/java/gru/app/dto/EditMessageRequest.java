package gru.app.dto;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class EditMessageRequest {

    private String content;

    public EditMessageRequest() {
    }

    public EditMessageRequest(String content) {
        this.content = content;
    }

}