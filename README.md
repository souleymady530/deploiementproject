# Configuration Docker Network pour Backends Spring Boot

Ce projet configure un réseau Docker personnalisé avec PostgreSQL, pgAdmin et vos services backend Spring Boot.

## 📋 Prérequis

- Docker installé
- Docker Compose installé
- Vos images Docker de backends Spring Boot

## 🚀 Démarrage rapide

### 1. Créer et démarrer le réseau avec PostgreSQL et pgAdmin

```bash
docker-compose up -d postgres pgadmin
```

### 2. Vérifier que les services sont démarrés

```bash
docker-compose ps
```

### 3. Accéder à pgAdmin

- URL: http://localhost:5050
- Email: `admin@admin.com`
- Mot de passe: `admin`

### 4. Configurer la connexion PostgreSQL dans pgAdmin

Dans pgAdmin, créez une nouvelle connexion serveur :
- **Host**: `postgres` (nom du service Docker)
- **Port**: `5432`
- **Database**: `mydb`
- **Username**: `postgres`
- **Password**: `postgres`

## 🔧 Ajouter vos backends Spring Boot

### Méthode 1: Modifier le docker-compose.yml

Décommentez et adaptez les sections `backend-service-1` et `backend-service-2` dans le fichier `docker-compose.yml` :

```yaml
backend-service-1:
  image: votre-image-backend-1:latest
  container_name: backend-service-1
  restart: unless-stopped
  environment:
    SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/mydb
    SPRING_DATASOURCE_USERNAME: postgres
    SPRING_DATASOURCE_PASSWORD: postgres
  ports:
    - "8081:8080"
  networks:
    - backend-network
  depends_on:
    postgres:
      condition: service_healthy
```

Puis démarrez :
```bash
docker-compose up -d
```

### Méthode 2: Ajouter manuellement des conteneurs au réseau

Si vos backends sont déjà en cours d'exécution :

```bash
# Connecter un conteneur existant au réseau
docker network connect backend-network nom-de-votre-conteneur

# Ou démarrer un nouveau conteneur sur le réseau
docker run -d \
  --name mon-backend \
  --network backend-network \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/mydb \
  -e SPRING_DATASOURCE_USERNAME=postgres \
  -e SPRING_DATASOURCE_PASSWORD=postgres \
  -p 8081:8080 \
  votre-image-backend:latest
```

## 📊 Commandes utiles

### Voir les logs
```bash
# Tous les services
docker-compose logs -f

# Un service spécifique
docker-compose logs -f postgres
docker-compose logs -f pgadmin
```

### Arrêter les services
```bash
docker-compose down
```

### Arrêter et supprimer les volumes (⚠️ supprime les données)
```bash
docker-compose down -v
```

### Lister les conteneurs sur le réseau
```bash
docker network inspect backend-network
```

### Redémarrer un service
```bash
docker-compose restart postgres
```

## 🔐 Configuration de sécurité

Pour la production, modifiez les variables d'environnement :

```yaml
environment:
  POSTGRES_DB: votre_db
  POSTGRES_USER: votre_user
  POSTGRES_PASSWORD: mot_de_passe_fort
  
  PGADMIN_DEFAULT_EMAIL: votre@email.com
  PGADMIN_DEFAULT_PASSWORD: mot_de_passe_fort
```

## 🌐 Réseau Docker

Le réseau `backend-network` permet à tous les services de communiquer entre eux :
- Les backends peuvent accéder à PostgreSQL via `postgres:5432`
- Les services peuvent se référencer par leur nom de service
- Le réseau est isolé de l'extérieur (sauf les ports exposés)

## 📝 Structure des volumes

Les données sont persistées dans des volumes Docker :
- `postgres-data`: Données de la base PostgreSQL
- `pgadmin-data`: Configuration de pgAdmin

## 🔍 Dépannage

### Le backend ne peut pas se connecter à PostgreSQL

Vérifiez que :
1. Le backend est sur le réseau `backend-network`
2. L'URL utilise le nom du service : `jdbc:postgresql://postgres:5432/mydb`
3. PostgreSQL est démarré : `docker-compose ps postgres`

### pgAdmin ne se connecte pas

1. Utilisez `postgres` comme hostname (pas `localhost`)
2. Vérifiez que les deux services sont sur le même réseau
3. Consultez les logs : `docker-compose logs pgadmin`

### Port déjà utilisé

Si le port 5432 ou 5050 est déjà utilisé, modifiez dans `docker-compose.yml` :
```yaml
ports:
  - "5433:5432"  # PostgreSQL sur le port 5433
  - "5051:80"    # pgAdmin sur le port 5051
```
