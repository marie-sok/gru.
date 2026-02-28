CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    phone VARCHAR(50) UNIQUE NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL,
    active BOOLEAN
);

CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    sender_id BIGINT,
    receiver_id BIGINT,
    text TEXT,
    timestamp TIMESTAMP
);