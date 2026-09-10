package gru.app.repository;

import gru.app.model.E2EERecoveryBackup;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface E2EERecoveryBackupRepository
        extends MongoRepository<E2EERecoveryBackup, String> {
}
