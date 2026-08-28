package gru.app.controller;

import gru.app.service.MediaStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class MediaController {

    private final MediaStorageService mediaStorageService;

    @GetMapping("/media/{fileName:.+}")
    public ResponseEntity<Resource> media(
            @PathVariable String fileName
    ) {
        Resource resource = mediaStorageService.load(fileName);
        String contentType = mediaStorageService.contentType(fileName);

        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "private, max-age=86400")
                .contentType(MediaType.parseMediaType(contentType))
                .body(resource);
    }
}
