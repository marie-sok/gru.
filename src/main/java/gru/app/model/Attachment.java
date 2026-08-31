package gru.app.model;

import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class Attachment {

    private UUID id = UUID.randomUUID();

    private String type;

    private String fileName;

    private String localPath;

    private String remoteURL;

    private Double width;

    private Double height;

    private Double duration;

    private List<Double> waveform;

    private long size;
}
