package gru.app.service;

import com.mongodb.client.gridfs.model.GridFSFile;
import org.bson.Document;
import org.springframework.core.io.Resource;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.gridfs.GridFsResource;
import org.springframework.data.mongodb.gridfs.GridFsTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.UUID;

@Service
public class MediaStorageService {

    private final GridFsTemplate gridFsTemplate;

    public MediaStorageService(GridFsTemplate gridFsTemplate) {
        this.gridFsTemplate = gridFsTemplate;
    }

    public StoredMedia save(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Media file is required"
            );
        }

        String original = file.getOriginalFilename();
        String extension = safeExtension(original);
        String storedName = UUID.randomUUID() + extension;
        String contentType = file.getContentType() == null
                ? "application/octet-stream"
                : file.getContentType();

        Document metadata = new Document()
                .append("originalFileName", original == null ? storedName : original)
                .append("contentType", contentType)
                .append("size", file.getSize());

        try {
            gridFsTemplate.store(
                    file.getInputStream(),
                    storedName,
                    contentType,
                    metadata
            );
        } catch (IOException error) {
            throw new ResponseStatusException(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "Could not store media"
            );
        }

        return new StoredMedia(
                storedName,
                original == null || original.isBlank() ? storedName : original,
                contentType,
                file.getSize()
        );
    }

    public Resource load(String storedName) {
        GridFSFile file = find(storedName);
        GridFsResource resource = gridFsTemplate.getResource(file);

        if (!resource.exists()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Media not found");
        }

        return resource;
    }

    public void deleteByRemoteURL(String remoteURL) {
        String storedName = storedNameFromRemoteURL(remoteURL);
        if (storedName == null) {
            return;
        }

        try {
            gridFsTemplate.delete(
                    Query.query(Criteria.where("filename").is(storedName))
            );
        } catch (RuntimeException ignored) {
            // Message deletion must remain reliable even if stale media cleanup fails.
        }
    }

    public String contentType(String storedName) {
        GridFSFile file = find(storedName);
        Document metadata = file.getMetadata();

        if (metadata != null) {
            String value = metadata.getString("contentType");
            if (value != null && !value.isBlank()) {
                return value;
            }
        }

        return "application/octet-stream";
    }

    private GridFSFile find(String storedName) {
        validateStoredName(storedName);

        GridFSFile file = gridFsTemplate.findOne(
                Query.query(Criteria.where("filename").is(storedName))
        );

        if (file == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Media not found");
        }

        return file;
    }

    private String storedNameFromRemoteURL(String remoteURL) {
        if (remoteURL == null || remoteURL.isBlank()) {
            return null;
        }

        String value = remoteURL.trim();
        int slash = value.lastIndexOf('/');
        String storedName = slash >= 0 ? value.substring(slash + 1) : value;

        if (!isValidStoredName(storedName)) {
            return null;
        }

        return storedName;
    }

    private void validateStoredName(String storedName) {
        if (!isValidStoredName(storedName)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid media name");
        }
    }

    private boolean isValidStoredName(String storedName) {
        return storedName != null
                && !storedName.isBlank()
                && !storedName.contains("..")
                && !storedName.contains("/")
                && !storedName.contains("\\");
    }

    private String safeExtension(String fileName) {
        if (fileName == null) {
            return "";
        }

        int dot = fileName.lastIndexOf('.');
        if (dot < 0 || dot == fileName.length() - 1) {
            return "";
        }

        String extension = fileName.substring(dot).toLowerCase();
        if (!extension.matches("\\.[a-z0-9]{1,10}")) {
            return "";
        }

        return extension;
    }

    public record StoredMedia(
            String storedName,
            String originalFileName,
            String contentType,
            long size
    ) {}
}
