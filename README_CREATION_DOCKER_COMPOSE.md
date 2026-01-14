# Guide de Création du docker-compose.yml - Étape par Étape

Ce guide explique comment créer un fichier `docker-compose.yml` professionnel pour une architecture avec PostgreSQL, pgAdmin et plusieurs backends Spring Boot.

## 📋 Table des Matières

1. [Structure de Base](#1-structure-de-base)
2. [Ajout de PostgreSQL](#2-ajout-de-postgresql)
3. [Ajout de pgAdmin](#3-ajout-de-pgadmin)
4. [Création du Réseau Docker](#4-création-du-réseau-docker)
5. [Ajout des Volumes](#5-ajout-des-volumes)
6. [Ajout des Backends Spring Boot](#6-ajout-des-backends-spring-boot)
7. [Amélioration avec Health Checks](#7-amélioration-avec-health-checks)
8. [Ajout des Resource Limits](#8-ajout-des-resource-limits)
9. [Configuration du Logging](#9-configuration-du-logging)
10. [Ajout du Service de Backup](#10-ajout-du-service-de-backup)
11. [Variables d'Environnement](#11-variables-denvironnement)
12. [Configuration Multi-Environnements](#12-configuration-multi-environnements)

---

## 1. Structure de Base

Commencez par créer un fichier `docker-compose.yml` avec la version et la structure de base :

```yaml
version: '3.8'

services:
  # Les services seront ajoutés ici

networks:
  # Les réseaux seront définis ici

volumes:
  # Les volumes seront définis ici
```

**Explication** :
- `version: '3.8'` : Version du format Docker Compose (3.8 est stable et largement supportée)
- `services:` : Section où tous les conteneurs seront définis
- `networks:` : Définition des réseaux personnalisés
- `volumes:` : Définition des volumes pour la persistance des données

---

## 2. Ajout de PostgreSQL

Ajoutez le service PostgreSQL dans la section `services:` :

```yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: postgres-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5433:5432"
```

**Explication ligne par ligne** :
- `postgres:` : Nom du service (utilisé pour la communication inter-conteneurs)
- `image: postgres:15-alpine` : Image Docker à utiliser (Alpine = version légère)
- `container_name: postgres-db` : Nom du conteneur (optionnel mais utile pour les logs)
- `restart: unless-stopped` : Redémarre automatiquement sauf si arrêté manuellement
- `environment:` : Variables d'environnement pour configurer PostgreSQL
  - `POSTGRES_DB` : Nom de la base de données à créer
  - `POSTGRES_USER` : Nom d'utilisateur administrateur
  - `POSTGRES_PASSWORD` : Mot de passe (⚠️ à changer en production)
- `ports:` : Mapping des ports (hôte:conteneur)
  - `"5434:5432"` : Port 5434 sur l'hôte → port 5432 dans le conteneur

---

## 3. Ajout de pgAdmin

Ajoutez pgAdmin pour gérer PostgreSQL graphiquement :

```yaml
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@admin.com
      PGADMIN_DEFAULT_PASSWORD: admin
      PGADMIN_CONFIG_SERVER_MODE: 'False'
    ports:
      - "5050:80"
    depends_on:
      - postgres
```

**Explication** :
- `depends_on:` : Indique que pgAdmin dépend de postgres (démarrage dans l'ordre)
- `PGADMIN_CONFIG_SERVER_MODE: 'False'` : Mode desktop (pas de multi-utilisateurs)
- Port 5050 sur l'hôte pour accéder à l'interface web

**Connexion à PostgreSQL depuis pgAdmin** :
- Host : `postgres` (nom du service, pas localhost)
- Port : `5432` (port interne, pas 5434)
- Database : `mydb`
- Username : `postgres`
- Password : `postgres`

---

## 4. Création du Réseau Docker

Ajoutez un réseau personnalisé pour isoler vos services :

```yaml
networks:
  backend-network:
    driver: bridge
    name: backend-network
```

Puis attachez les services au réseau :

```yaml
services:
  postgres:
    # ... configuration existante ...
    networks:
      - backend-network
  
  pgadmin:
    # ... configuration existante ...
    networks:
      - backend-network
```

**Explication** :
- `driver: bridge` : Type de réseau (bridge = réseau local entre conteneurs)
- `name: backend-network` : Nom explicite du réseau
- Les services sur le même réseau peuvent communiquer entre eux par leur nom

**Avantages** :
- Isolation des services
- Communication par nom de service (DNS automatique)
- Sécurité accrue

---

## 5. Ajout des Volumes

Ajoutez des volumes pour persister les données :

```yaml
volumes:
  postgres-data:
    driver: local
  pgadmin-data:
    driver: local
```

Puis attachez-les aux services :

```yaml
services:
  postgres:
    # ... configuration existante ...
    volumes:
      - postgres-data:/var/lib/postgresql/data
  
  pgadmin:
    # ... configuration existante ...
    volumes:
      - pgadmin-data:/var/lib/pgadmin
```

**Explication** :
- `postgres-data:/var/lib/postgresql/data` : 
  - `postgres-data` : Nom du volume (géré par Docker)
  - `/var/lib/postgresql/data` : Chemin dans le conteneur où PostgreSQL stocke ses données
- Les données survivent à la suppression du conteneur

**Avantages** :
- Persistance des données
- Facilité de backup
- Indépendance du cycle de vie du conteneur

---

## 6. Ajout des Backends Spring Boot

Ajoutez vos services backend :

```yaml
  backend-service-1:
    image: votre-image-backend-1:latest
    container_name: backend-service-1
    restart: unless-stopped
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/mydb
      SPRING_DATASOURCE_USERNAME: postgres
      SPRING_DATASOURCE_PASSWORD: postgres
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
    ports:
      - "8081:8080"
    networks:
      - backend-network
    depends_on:
      - postgres
```

**Explication** :
- `SPRING_DATASOURCE_URL` : URL JDBC pour se connecter à PostgreSQL
  - `postgres` : Nom du service (résolu par DNS Docker)
  - `5432` : Port interne (pas 5434)
- `SPRING_JPA_HIBERNATE_DDL_AUTO: update` : Hibernate met à jour le schéma automatiquement
- Port 8081 sur l'hôte pour accéder à l'API

**Pour ajouter plusieurs backends** :
Dupliquez la configuration en changeant :
- Le nom du service (`backend-service-2`)
- Le nom du conteneur
- Le port hôte (`8082:8080`)
- L'image Docker

---

## 7. Amélioration avec Health Checks

Ajoutez des health checks pour surveiller l'état des services :

### PostgreSQL Health Check

```yaml
  postgres:
    # ... configuration existante ...
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
```

**Explication** :
- `test` : Commande pour vérifier la santé (pg_isready vérifie si PostgreSQL accepte les connexions)
- `interval: 10s` : Vérification toutes les 10 secondes
- `timeout: 5s` : Timeout de 5 secondes pour la commande
- `retries: 5` : 5 échecs consécutifs = unhealthy
- `start_period: 30s` : Période de grâce au démarrage (échecs ignorés)

### Backend Health Check

```yaml
  backend-service-1:
    # ... configuration existante ...
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Prérequis** :
- Spring Boot Actuator doit être activé
- `curl` doit être installé dans l'image Docker

### Dépendance avec Health Check

```yaml
  backend-service-1:
    depends_on:
      postgres:
        condition: service_healthy
```

**Avantage** : Le backend ne démarre que quand PostgreSQL est vraiment prêt (pas juste démarré)

---

## 8. Ajout des Resource Limits

Limitez les ressources pour éviter qu'un service monopolise le système :

```yaml
  postgres:
    # ... configuration existante ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

**Explication** :
- `limits` : Maximum de ressources utilisables
  - `cpus: '2'` : Maximum 2 cœurs CPU
  - `memory: 2G` : Maximum 2 Go de RAM
- `reservations` : Ressources garanties
  - `cpus: '1'` : Au moins 1 cœur garanti
  - `memory: 1G` : Au moins 1 Go garanti

**Recommandations par service** :

| Service | CPU Limit | Memory Limit | CPU Reserved | Memory Reserved |
|---------|-----------|--------------|--------------|-----------------|
| PostgreSQL | 2 | 2G | 1 | 1G |
| Backend | 1 | 1G | 0.5 | 512M |
| pgAdmin | 0.5 | 512M | 0.25 | 256M |

---

## 9. Configuration du Logging

Configurez la rotation des logs pour éviter de saturer le disque :

```yaml
  backend-service-1:
    # ... configuration existante ...
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Explication** :
- `driver: "json-file"` : Format JSON pour les logs
- `max-size: "10m"` : Taille maximale d'un fichier de log (10 Mo)
- `max-file: "3"` : Nombre maximum de fichiers (rotation)
- Total : 30 Mo maximum de logs par service

**Ajout de labels pour le monitoring** :

```yaml
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,environment"
    labels:
      com.example.service: "backend-1"
      com.example.environment: "dev"
```

---

## 10. Ajout du Service de Backup

Ajoutez un service pour sauvegarder automatiquement PostgreSQL :

```yaml
  postgres-backup:
    image: prodrigestivill/postgres-backup-local
    container_name: postgres-backup
    restart: unless-stopped
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_DB: mydb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      SCHEDULE: "@daily"
      BACKUP_KEEP_DAYS: 7
      BACKUP_KEEP_WEEKS: 4
      BACKUP_KEEP_MONTHS: 6
    volumes:
      - ./backups:/backups
    networks:
      - backend-network
    depends_on:
      postgres:
        condition: service_healthy
```

**Explication** :
- `SCHEDULE: "@daily"` : Backup quotidien (autres options : @hourly, @weekly, ou cron)
- `BACKUP_KEEP_DAYS: 7` : Garde les backups quotidiens pendant 7 jours
- `BACKUP_KEEP_WEEKS: 4` : Garde un backup hebdomadaire pendant 4 semaines
- `BACKUP_KEEP_MONTHS: 6` : Garde un backup mensuel pendant 6 mois
- `./backups:/backups` : Stocke les backups sur l'hôte (dans le dossier ./backups)

**Restaurer un backup** :
```bash
docker exec -i postgres-db psql -U postgres -d mydb < backups/mydb-2024-01-14.sql
```

---

## 11. Variables d'Environnement

Remplacez les valeurs en dur par des variables d'environnement :

### Créer un fichier `.env`

```env
# PostgreSQL
POSTGRES_DB=mydb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=ChangeMeInProduction123!
POSTGRES_PORT=5434

# pgAdmin
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=ChangeMeInProduction456!
PGADMIN_PORT=5050

# Backend
BACKEND_1_IMAGE=backend-service-1:1.0.0
BACKEND_1_PORT=8081
```

### Utiliser les variables dans docker-compose.yml

```yaml
services:
  postgres:
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "${POSTGRES_PORT}:5432"
  
  backend-service-1:
    image: ${BACKEND_1_IMAGE}
    ports:
      - "${BACKEND_1_PORT}:8080"
```

**Avec valeurs par défaut** :

```yaml
environment:
  POSTGRES_DB: ${POSTGRES_DB:-mydb}
  POSTGRES_USER: ${POSTGRES_USER:-postgres}
```

Syntaxe : `${VARIABLE:-valeur_par_defaut}`

**Avantages** :
- Sécurité : `.env` peut être exclu du versioning (`.gitignore`)
- Flexibilité : Différentes configurations sans modifier le docker-compose.yml
- Facilité : Changement rapide des paramètres

---

## 12. Configuration Multi-Environnements

Créez des fichiers de configuration par environnement :

### Structure

```
deploiement-project/
├── docker-compose.yml          # Configuration de base
├── docker-compose.dev.yml      # Overrides développement
├── docker-compose.staging.yml  # Overrides staging
├── docker-compose.prod.yml     # Overrides production
├── .env.dev
├── .env.staging
└── .env.prod
```

### docker-compose.yml (base)

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    # Configuration commune
```

### docker-compose.dev.yml (overrides développement)

```yaml
version: '3.8'

services:
  postgres:
    ports:
      - "5433:5432"  # Port exposé en dev
    environment:
      POSTGRES_PASSWORD: postgres  # Mot de passe simple en dev
  
  backend-service-1:
    environment:
      SPRING_PROFILES_ACTIVE: dev
      SPRING_JPA_SHOW_SQL: true  # Logs SQL en dev
```

### docker-compose.prod.yml (overrides production)

```yaml
version: '3.8'

services:
  postgres:
    # Pas de port exposé en production (sécurité)
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 4G
      restart_policy:
        condition: on-failure
        max_attempts: 3
  
  backend-service-1:
    environment:
      SPRING_PROFILES_ACTIVE: prod
      SPRING_JPA_HIBERNATE_DDL_AUTO: validate  # Pas de modification auto du schéma
    deploy:
      replicas: 3  # 3 instances pour haute disponibilité
```

### Utilisation

```bash
# Développement
docker-compose -f docker-compose.yml -f docker-compose.dev.yml --env-file .env.dev up -d

# Staging
docker-compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging up -d

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod up -d
```

**Principe** :
- Le fichier de base contient la configuration commune
- Les fichiers d'override ajoutent ou remplacent des configurations spécifiques
- Docker Compose fusionne automatiquement les fichiers dans l'ordre

---

## 📚 Résumé des Bonnes Pratiques

### ✅ À Faire

1. **Utiliser des versions spécifiques** : `postgres:15-alpine` plutôt que `postgres:latest`
2. **Nommer explicitement** : Donner des noms clairs aux services, réseaux et volumes
3. **Ajouter des health checks** : Sur tous les services critiques
4. **Limiter les ressources** : Éviter qu'un service monopolise le système
5. **Configurer le logging** : Rotation des logs pour éviter de saturer le disque
6. **Utiliser des variables d'environnement** : Ne jamais mettre de secrets en dur
7. **Séparer les environnements** : Fichiers différents pour dev/staging/prod
8. **Documenter** : Commenter les configurations non évidentes
9. **Sauvegarder** : Mettre en place des backups automatiques
10. **Tester** : Valider avec `docker-compose config` avant de déployer

### ❌ À Éviter

1. **Mots de passe en dur** : Toujours utiliser des variables d'environnement
2. **Tag `latest`** : Préférer des versions spécifiques pour la reproductibilité
3. **Pas de health checks** : Risque de dépendances non prêtes
4. **Pas de resource limits** : Un service peut faire crasher tout le système
5. **Logs non limités** : Peut saturer le disque
6. **Port 5432 exposé en production** : Risque de sécurité
7. **Pas de backups** : Perte de données en cas de problème
8. **Un seul fichier pour tous les environnements** : Difficile à maintenir

---

## 🚀 Commandes Utiles

```bash
# Valider la syntaxe
docker-compose config

# Démarrer en arrière-plan
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Voir l'état des services
docker-compose ps

# Arrêter les services
docker-compose down

# Arrêter et supprimer les volumes
docker-compose down -v

# Reconstruire les images
docker-compose build

# Redémarrer un service
docker-compose restart postgres

# Voir les ressources utilisées
docker stats
```

---

## 📖 Exemple Complet Final

Voici le fichier `docker-compose.yml` complet avec toutes les bonnes pratiques :

```yaml
version: '3.8'

services:
  # Base de données PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: postgres-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-mydb}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "${POSTGRES_PORT:-5434}:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - backend-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

  # pgAdmin
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD}
      PGADMIN_CONFIG_SERVER_MODE: 'False'
    ports:
      - "${PGADMIN_PORT:-5050}:80"
    volumes:
      - pgadmin-data:/var/lib/pgadmin
    networks:
      - backend-network
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # Service de backup
  postgres-backup:
    image: prodrigestivill/postgres-backup-local
    container_name: postgres-backup
    restart: unless-stopped
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_DB: ${POSTGRES_DB:-mydb}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      SCHEDULE: "@daily"
      BACKUP_KEEP_DAYS: 7
      BACKUP_KEEP_WEEKS: 4
      BACKUP_KEEP_MONTHS: 6
    volumes:
      - ./backups:/backups
    networks:
      - backend-network
    depends_on:
      postgres:
        condition: service_healthy

  # Backend Spring Boot (exemple)
  backend-service-1:
    image: ${BACKEND_1_IMAGE}
    container_name: backend-service-1
    restart: unless-stopped
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/${POSTGRES_DB:-mydb}
      SPRING_DATASOURCE_USERNAME: ${POSTGRES_USER:-postgres}
      SPRING_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD}
      SPRING_JPA_HIBERNATE_DDL_AUTO: ${HIBERNATE_DDL_AUTO:-update}
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILE:-dev}
    ports:
      - "${BACKEND_1_PORT:-8081}:8080"
    networks:
      - backend-network
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  backend-network:
    driver: bridge
    name: backend-network

volumes:
  postgres-data:
    driver: local
  pgadmin-data:
    driver: local
```

Ce fichier est prêt pour la production avec toutes les bonnes pratiques appliquées ! 🎉
