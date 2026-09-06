package gru.app.service;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ContentSafetyServiceTest {

    @Test
    void acceptsNormalMessage() {
        ContentSafetyService service = new ContentSafetyService("spam,blocked phrase");

        assertDoesNotThrow(() -> service.validateText("Привет! Как дела?"));
    }

    @Test
    void rejectsConfiguredBlockedTermIgnoringCase() {
        ContentSafetyService service = new ContentSafetyService("spam,blocked phrase");

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> service.validateText("This contains SPAM")
        );

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, error.getStatusCode());
    }

    @Test
    void rejectsMoreThanThreeLinks() {
        ContentSafetyService service = new ContentSafetyService("");

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> service.validateText(
                        "https://one.test https://two.test www.three.test https://four.test"
                )
        );

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, error.getStatusCode());
    }

    @Test
    void rejectsOversizedMessage() {
        ContentSafetyService service = new ContentSafetyService("");

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> service.validateText("a".repeat(10_001))
        );

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, error.getStatusCode());
    }
}
