-- Todo table will be created in the database specified by POSTGRES_DB env variable
-- PostgreSQL automatically creates this database on startup

CREATE TABLE IF NOT EXISTS todo(
    todo_id SERIAL PRIMARY KEY,
    description VARCHAR(255)
);
