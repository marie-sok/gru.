package gru.app.repository;

import gru.app.model.AbuseReport;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface AbuseReportRepository extends MongoRepository<AbuseReport, String> {
    void deleteByReporterId(String reporterId);
    void deleteByTargetUserId(String targetUserId);
}
