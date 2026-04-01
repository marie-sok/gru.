CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(100) UNIQUE NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    active BOOLEAN
);
