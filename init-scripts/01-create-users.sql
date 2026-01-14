-- Script d'initialisation PostgreSQL
-- Ce script crée des utilisateurs avec privilèges limités pour chaque backend

-- Créer un utilisateur pour le backend 1
CREATE USER backend1_user WITH PASSWORD 'backend1_password';
GRANT CONNECT ON DATABASE mydb TO backend1_user;

-- Créer un utilisateur pour le backend 2
CREATE USER backend2_user WITH PASSWORD 'backend2_password';
GRANT CONNECT ON DATABASE mydb TO backend2_user;

-- Note: Les privilèges sur les tables seront accordés après leur création
-- Vous pouvez ajouter ces commandes dans vos migrations Flyway/Liquibase :
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO backend1_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO backend1_user;
