# Plan de Déploiement CI/CD avec GitHub Actions

## Contexte
- **Plateforme CI/CD:** GitHub Actions
- **Cible de déploiement:** Serveur VPS/Dédié via SSH (déjà configuré)
- **Transfert d'image:** Direct via SSH (sans registre Docker)
- **Architecture:** Application unifiée (Frontend Angular intégré dans le JAR Spring Boot)
- **Base de données:** Déjà déployée sur le VPS avec le réseau configuré
- **Forgejo:** Mirror de sauvegarde (lecture seule)

---

## Architecture Globale

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           GITHUB                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                    Repo Application                                  │ │
│  │  ┌─────────────────┐        ┌─────────────────┐                     │ │
│  │  │ /frontend       │  ───▶  │ /backend        │                     │ │
│  │  │ (Angular)       │  build │ (Spring Boot)   │                     │ │
│  │  └─────────────────┘   +    └────────┬────────┘                     │ │
│  │                        copie         │                               │ │
│  │                                      ▼                               │ │
│  │                         ┌─────────────────────┐                      │ │
│  │                         │ JAR Unifié          │                      │ │
│  │                         │ (backend + frontend)│                      │ │
│  │                         └─────────────────────┘                      │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                      │                                    │
│                           GitHub Actions                                  │
│                                      │                                    │
│                                      ▼                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │  1. Build Image Docker                                               │ │
│  │  2. docker save | gzip → image.tar.gz                               │ │
│  │  3. scp image.tar.gz → VPS                                          │ │
│  │  4. ssh: docker load < image.tar.gz                                 │ │
│  │  5. ssh: docker-compose up -d                                       │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ SSH + SCP
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           SERVEUR VPS                                     │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │  Infrastructure existante (backend-network)                  │         │
│  │    ├── postgres-db (déjà en place)                          │         │
│  │    ├── pgadmin                                               │         │
│  │    └── monitoring (prometheus, grafana, loki)               │         │
│  └─────────────────────────────────────────────────────────────┘         │
│                                                                           │
│  Applications déployées:                                                  │
│    ├── gestion-unified:3333                                              │
│    ├── nordtext-unified:8080                                             │
│    └── sgmao-unified:9999                                                │
└──────────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────────────┐
                    │        FORGEJO           │
                    │   (Mirror de sauvegarde) │
                    │      Lecture seule       │
                    └──────────────────────────┘
```

---

## Processus de Build et Déploiement

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  1. Build       │     │  2. Copier      │     │  3. Build       │
│  Frontend       │ ──▶ │  dans Backend   │ ──▶ │  Backend + JAR  │
│  npm run build  │     │  static/        │     │  mvn package    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  6. Charger     │     │  5. Transférer  │     │  4. Build       │
│  docker load    │ ◀── │  via SCP        │ ◀── │  Image Docker   │
│  + restart      │     │  image.tar.gz   │     │  docker save    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## Fichiers à Créer

### Dans chaque repo d'application (sur GitHub)

| Fichier | Description |
|---------|-------------|
| `.github/workflows/ci-cd.yml` | Workflow GitHub Actions |
| `Dockerfile` | Dockerfile multi-stage (Angular + Spring Boot) |

### Dans ce projet (deploiementproject) - sur le VPS

| Fichier | Description |
|---------|-------------|
| `docker-compose.apps.yml` | Docker-compose pour les applications unifiées |
| `.env` | Variables d'environnement de production |

---

## Structure d'un Repo Application

```
mon-application/
├── frontend/                    # Code Angular
│   ├── src/
│   ├── package.json
│   └── angular.json
├── backend/                     # Code Spring Boot
│   ├── src/
│   │   └── main/
│   │       └── resources/
│   │           └── static/      # ← Frontend buildé copié ici
│   └── pom.xml
├── Dockerfile                   # Build multi-stage
└── .github/
    └── workflows/
        └── ci-cd.yml            # Workflow GitHub Actions
```

---

## Secrets GitHub à Configurer

Dans chaque repo GitHub: **Settings → Secrets and variables → Actions**

| Secret | Description | Exemple |
|--------|-------------|---------|
| `VPS_HOST` | Adresse IP ou domaine du serveur | `192.168.1.100` |
| `VPS_USER` | Utilisateur SSH | `deploy` |
| `VPS_SSH_KEY` | Clé privée SSH | `-----BEGIN OPENSSH...` |
| `VPS_DEPLOY_PATH` | Chemin de déploiement | `/opt/apps` |

### Comment créer la clé SSH

```bash
# Sur ta machine locale
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy

# Copier la clé publique sur le VPS
ssh-copy-id -i ~/.ssh/github_deploy.pub deploy@ton-vps.com

# La clé privée (~/.ssh/github_deploy) va dans le secret VPS_SSH_KEY
cat ~/.ssh/github_deploy
```

---

## Workflow GitHub Actions (ci-cd.yml)

```yaml
name: CI/CD Application Unifiée

on:
  push:
    branches: [main]
    tags: ['v*.*.*']
  pull_request:
    branches: [main]

env:
  IMAGE_NAME: mon-app
  CONTAINER_NAME: mon-app-container

jobs:
  # ═══════════════════════════════════════════════════════════
  # JOB 1: Tests
  # ═══════════════════════════════════════════════════════════
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Tests Frontend
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Tests Frontend
        working-directory: frontend
        run: |
          npm ci
          npm run lint
          # npm run test -- --watch=false --browsers=ChromeHeadless

      # Tests Backend
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'maven'

      - name: Tests Backend
        working-directory: backend
        run: mvn test

  # ═══════════════════════════════════════════════════════════
  # JOB 2: Build et Déploiement
  # ═══════════════════════════════════════════════════════════
  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Déterminer la version
      - name: Déterminer la version
        id: version
        run: |
          if [[ $GITHUB_REF == refs/tags/v* ]]; then
            echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
          else
            echo "VERSION=latest" >> $GITHUB_OUTPUT
          fi

      # Build Image Docker (multi-stage)
      - name: Build Image Docker
        run: |
          docker build -t ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.VERSION }} .

      # Sauvegarder et compresser l'image
      - name: Sauvegarder l'image
        run: |
          docker save ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.VERSION }} | gzip > image.tar.gz
          ls -lh image.tar.gz

      # Configurer SSH
      - name: Configurer SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.VPS_SSH_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts

      # Transférer l'image vers le VPS
      - name: Transférer l'image vers VPS
        run: |
          scp -i ~/.ssh/deploy_key image.tar.gz ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }}:/tmp/

      # Déployer sur le VPS
      - name: Déployer sur VPS
        run: |
          ssh -i ~/.ssh/deploy_key ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }} << 'ENDSSH'
            set -e

            echo "📦 Chargement de l'image Docker..."
            docker load < /tmp/image.tar.gz
            rm /tmp/image.tar.gz

            echo "🔄 Redémarrage du conteneur..."
            cd ${{ secrets.VPS_DEPLOY_PATH }}
            docker-compose -f docker-compose.apps.yml up -d --no-deps ${{ env.CONTAINER_NAME }}

            echo "⏳ Attente du démarrage..."
            sleep 15

            echo "✅ Vérification de la santé..."
            docker-compose -f docker-compose.apps.yml ps

            echo "🎉 Déploiement terminé!"
          ENDSSH

      # Nettoyage
      - name: Nettoyage
        run: rm -f ~/.ssh/deploy_key
```

---

## Dockerfile Multi-Stage Unifié

```dockerfile
# ═══════════════════════════════════════════════════════════
# Étape 1: Build Frontend Angular
# ═══════════════════════════════════════════════════════════
FROM node:20-alpine AS frontend-build

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --silent
COPY frontend/ ./
RUN npm run build -- --configuration=production

# ═══════════════════════════════════════════════════════════
# Étape 2: Build Backend Spring Boot
# ═══════════════════════════════════════════════════════════
FROM maven:3.9-eclipse-temurin-17 AS backend-build

WORKDIR /app

# Télécharger les dépendances (cache)
COPY backend/pom.xml ./
RUN mvn dependency:go-offline -B

# Copier le code source
COPY backend/src ./src

# Copier le frontend buildé dans les ressources statiques
COPY --from=frontend-build /app/frontend/dist/*/browser/ ./src/main/resources/static/

# Build du JAR
RUN mvn package -DskipTests -B

# ═══════════════════════════════════════════════════════════
# Étape 3: Image finale légère
# ═══════════════════════════════════════════════════════════
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Créer un utilisateur non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copier le JAR
COPY --from=backend-build /app/target/*.jar app.jar

# Variables d'environnement
ENV JAVA_OPTS="-Xms256m -Xmx512m"

# Port exposé (à adapter selon l'application)
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

# Démarrage
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

---

## Docker-Compose Applications (docker-compose.apps.yml)

À placer sur le VPS dans `/opt/apps/`

```yaml
version: '3.8'

# Applications unifiées (frontend + backend dans un seul conteneur)

services:
  # ═══════════════════════════════════════════════════════════
  # Application Gestion
  # ═══════════════════════════════════════════════════════════
  gestion-app:
    image: gestion-unified:latest
    container_name: gestion-app
    restart: unless-stopped
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-db:5432/${POSTGRES_DB:-mydb}
      SPRING_DATASOURCE_USERNAME: ${POSTGRES_USER:-postgres}
      SPRING_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      SPRING_PROFILES_ACTIVE: prod
      SERVER_PORT: 3333
    ports:
      - "3333:3333"
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3333/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # ═══════════════════════════════════════════════════════════
  # Application NordText
  # ═══════════════════════════════════════════════════════════
  nordtext-app:
    image: nordtext-unified:latest
    container_name: nordtext-unified-container
    restart: unless-stopped
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-db:5432/${POSTGRES_DB:-mydb}
      SPRING_DATASOURCE_USERNAME: ${POSTGRES_USER:-postgres}
      SPRING_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      SPRING_PROFILES_ACTIVE: prod
      SERVER_PORT: 8080
    ports:
      - "8080:8080"
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # ═══════════════════════════════════════════════════════════
  # Application SGMAO
  # ═══════════════════════════════════════════════════════════
  sgmao-app:
    image: sgmao-unified:latest
    container_name: sgmao-api
    restart: unless-stopped
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-db:5432/${POSTGRES_DB:-mydb}
      SPRING_DATASOURCE_USERNAME: ${POSTGRES_USER:-postgres}
      SPRING_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      SPRING_PROFILES_ACTIVE: prod
      SERVER_PORT: 9999
    ports:
      - "9999:9999"
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9999/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  backend-network:
    external: true
```

---

## Commandes Manuelles (sur le VPS)

```bash
# Voir les conteneurs
docker-compose -f docker-compose.apps.yml ps

# Voir les logs d'une application
docker logs -f gestion-app

# Redémarrer une application
docker-compose -f docker-compose.apps.yml restart gestion-app

# Arrêter une application
docker-compose -f docker-compose.apps.yml stop gestion-app

# Vérifier la santé
curl http://localhost:3333/actuator/health
```

---

## Étapes d'Implémentation

### 1. Sur le VPS
```bash
# Créer le répertoire
sudo mkdir -p /opt/apps
sudo chown deploy:deploy /opt/apps

# Copier docker-compose.apps.yml
# Créer le fichier .env avec les variables
```

### 2. Sur GitHub (pour chaque repo)
1. Ajouter les secrets (VPS_HOST, VPS_USER, VPS_SSH_KEY, VPS_DEPLOY_PATH)
2. Copier `.github/workflows/ci-cd.yml`
3. Copier `Dockerfile` à la racine
4. Adapter les variables (IMAGE_NAME, CONTAINER_NAME, ports)

### 3. Premier déploiement
```bash
git add .
git commit -m "feat: ajout CI/CD GitHub Actions"
git push origin main
```

---

## Dépannage

### L'image ne se charge pas
```bash
# Vérifier l'espace disque
df -h

# Nettoyer les anciennes images
docker image prune -a
```

### Le conteneur ne démarre pas
```bash
# Voir les logs
docker logs gestion-app

# Vérifier les variables d'environnement
docker inspect gestion-app | grep -A 20 "Env"
```

### Problème de connexion SSH
```bash
# Tester la connexion manuellement
ssh -i ~/.ssh/github_deploy deploy@ton-vps.com
```
