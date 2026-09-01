package gru.app.dto;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class EditMessageRequest {

    private String text;
    private String content;

    public EditMessageRequest() {
    }

    public EditMessageRequest(String text) {
        this.text = text;
        this.content = text;
    }

    public String resolveText() {
        if (text != null && !text.isBlank()) return text;
        return content;
    }
}
