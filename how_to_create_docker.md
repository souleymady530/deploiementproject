# Guide : Dockeriser une application Spring Boot pour l'Architecture Professionnelle

Ce guide explique comment créer une configuration Docker professionnelle pour une application Spring Boot, en s'appuyant sur les standards de sécurité, de performance et d'isolation réseau établis pour vos projets.

---

## 🏗️ 1. Le Dockerfile Multi-Stage

Le Dockerfile est le cœur de votre image. Utilisez une approche **multi-stage** pour séparer la construction (Maven) de l'exécution (JRE), garantissant une image finale légère et sécurisée.

Créez un fichier `Dockerfile` à la racine de votre projet :

```dockerfile
# --- Étape 1 : Construction (Build) ---
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copie du pom.xml et du code source
COPY pom.xml .
COPY src ./src

# Construction du JAR (skip tests pour plus de rapidité)
RUN mvn clean package -DskipTests -B

# --- Étape 2 : Exécution (Runtime) ---
FROM eclipse-temurin:17-jre
WORKDIR /app

# Sécurité : Création d'un utilisateur non-root
RUN groupadd -r spring && useradd -r -g spring spring

# Préparation des répertoires (logs, uploads, etc.)
RUN mkdir -p /app/logs /app/uploads && \
    chown -R spring:spring /app

# Installation de curl pour les Health Checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copie du JAR généré à l'étape précédente
COPY --from=build --chown=spring:spring /app/target/*.jar app.jar

# Utilisation de l'utilisateur sécurisé
USER spring:spring

# Configuration JVM optimisée
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC"

# Exposition du port (à adapter selon votre application)
EXPOSE 8080

# Commande de démarrage
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

# Health Check automatique
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
```

---

## 🐳 2. Le fichier docker-compose.yml

Le `docker-compose.yml` définit comment votre application interagit avec d'autres services (comme PostgreSQL) sur le réseau partagé.

```yaml
services:
  mon-app-api:
    build:
      context: .
      dockerfile: Dockerfile
    image: mon-app-backend:${APP_VERSION:-1.0.0}
    container_name: mon-app-container
    restart: unless-stopped
    
    # Variables d'environnement basées sur le .env
    environment:
      # Connexion DB (utilise le nom de service 'postgres' sur le réseau)
      SPRING_DATASOURCE_URL: ${DB_URL:-jdbc:postgresql://postgres:5432/ma_db}
      SPRING_DATASOURCE_USERNAME: ${DB_USER:-postgres}
      SPRING_DATASOURCE_PASSWORD: ${DB_PASS:-postgres}
      
      # Configuration Spring
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-dev}
      JAVA_OPTS: ${JAVA_OPTS:--Xms512m -Xmx1024m}
    
    ports:
      - "${PORT_EXPOSE:-8080}:8080"
    
    volumes:
      - ./logs:/app/logs
      - ./uploads:/app/uploads
    
    # Intégration au réseau partagé
    networks:
      - backend-network
    
    # Limites de ressources (CPU/RAM)
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

networks:
  backend-network:
    external: true
    name: backend-network
```

---

## ⚙️ 3. Configuration Spring Boot (`application.properties`)

Pour que Docker puisse injecter les configurations, utilisez des **placeholders** dans votre fichier `application.properties` ou `application.yml` :

```properties
# Utilise la variable d'env si présente, sinon la valeur par défaut
spring.datasource.url=${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5432/ma_db}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME:postgres}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD:postgres}

# Activer Actuator pour les Health Checks Docker
management.endpoints.web.exposure.include=health,info,prometheus
management.endpoint.health.show-details=always
```

---

## 🔐 4. Gestion des secrets (`.env.example`)

Ne mettez jamais de mots de passe en dur. Créez un fichier `.env.example` pour documenter les variables nécessaires :

```bash
# Docker Configuration
APP_VERSION=1.0.0
PORT_EXPOSE=8080

# Database Configuration
DB_URL=jdbc:postgresql://postgres:5432/nom_de_la_db
DB_USER=postgres
DB_PASS=votre_mot_de_passe_securise
```

---

## 🚀 Étapes de Déploiement

1.  **Préparer le projet** : Ajoutez le `Dockerfile`, `docker-compose.yml` et `.env.example`.
2.  **Créer le réseau** : `docker network create backend-network` (si pas déjà fait).
3.  **Configurer** : `cp .env.example .env` et éditez les valeurs.
4.  **Lancer** : `docker compose up -d --build`.

> [!TIP]
> **Pourquoi le multi-stage build ?**
> Cela permet de ne pas inclure Maven et les fichiers sources dans l'image finale, ce qui réduit la taille de l'image (environ 200Mo au lieu de 600Mo) et améliore la sécurité.
