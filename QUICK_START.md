# 🚀 Guide de Démarrage Rapide

## Structure du Projet

```
deploiement-project/
├── docker-compose.yml              # Configuration de base
├── docker-compose.improved.yml     # Version améliorée (recommandée)
├── docker-compose.prod.yml         # Overrides pour production
├── docker-compose.monitoring.yml   # Stack de monitoring
├── .env.example                    # Template des variables d'environnement
├── init-scripts/                   # Scripts d'initialisation PostgreSQL
│   └── 01-create-users.sql
├── monitoring/                     # Configuration monitoring
│   ├── prometheus.yml
│   └── grafana/
│       ├── datasources/
│       └── dashboards/
└── backups/                        # Backups PostgreSQL (créé automatiquement)
```

## 📋 Étapes de Configuration

### 1. Créer le fichier .env

```bash
cp .env.example .env
# Éditez .env et changez les mots de passe !
```

### 2. Démarrage Simple (Développement)

```bash
# Avec la configuration de base
docker-compose up -d

# OU avec la configuration améliorée (recommandé)
docker-compose -f docker-compose.improved.yml up -d
```

### 3. Démarrage avec Monitoring

```bash
docker-compose -f docker-compose.improved.yml -f docker-compose.monitoring.yml up -d
```

### 4. Démarrage Production

```bash
docker-compose -f docker-compose.improved.yml -f docker-compose.prod.yml up -d
```

## 🔗 Accès aux Services

| Service | URL | Identifiants par défaut |
|---------|-----|------------------------|
| **pgAdmin** | http://localhost:5050 | admin@example.com / (voir .env) |
| **PostgreSQL** | localhost:5433 | postgres / (voir .env) |
| **Prometheus** | http://localhost:9090 | - |
| **Grafana** | http://localhost:3000 | admin / (voir .env) |
| **cAdvisor** | http://localhost:8080 | - |

## ✅ Vérifications

```bash
# Voir l'état des services
docker-compose ps

# Voir les logs
docker-compose logs -f

# Vérifier le réseau
docker network inspect backend-network

# Tester la connexion PostgreSQL
docker exec -it postgres-db psql -U postgres -d mydb
```

## 🔧 Ajouter vos Backends

### Option 1: Modifier docker-compose.improved.yml

1. Décommentez les sections `backend-service-1` et `backend-service-2`
2. Modifiez les variables dans `.env`:
   ```env
   BACKEND_1_IMAGE=votre-image:1.0.0
   BACKEND_1_PORT=8081
   ```
3. Redémarrez:
   ```bash
   docker-compose -f docker-compose.improved.yml up -d
   ```

### Option 2: Connecter un conteneur existant

```bash
docker network connect backend-network nom-de-votre-backend
```

## 📊 Monitoring

Une fois Grafana démarré:

1. Accédez à http://localhost:3000
2. Connectez-vous (admin / voir .env)
3. Importez des dashboards:
   - Dashboard ID 9628 (PostgreSQL)
   - Dashboard ID 193 (Docker)
   - Dashboard ID 4701 (JVM Micrometer)

## 💾 Backups

Les backups PostgreSQL sont automatiques (quotidiens par défaut).

```bash
# Voir les backups
ls -lh backups/

# Restaurer un backup
docker exec -i postgres-db psql -U postgres -d mydb < backups/mydb-YYYY-MM-DD.sql
```

## 🛑 Arrêter les Services

```bash
# Arrêter sans supprimer les données
docker-compose down

# Arrêter et supprimer les volumes (⚠️ SUPPRIME LES DONNÉES)
docker-compose down -v
```

## 📚 Documentation Complète

Consultez `architecture_recommendations.md` pour:
- Recommandations de sécurité
- Stratégies de haute disponibilité
- Configuration avancée
- Checklist de production
