#!/bin/bash
# =============================================================================
# Script de déploiement SSH pour les applications
# Usage: ./deployer.sh [service_name] [image_tag]
# =============================================================================

set -euo pipefail

# Configuration (peut être surchargée par variables d'environnement)
DEPLOY_PATH="${DEPLOY_PATH:-/opt/apps/deploiementproject}"
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.apps.yml -f docker-compose.monitoring.yml"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour afficher l'usage
usage() {
    echo "Usage: $0 [options] [service_name] [image_tag]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Afficher cette aide"
    echo "  -a, --all           Déployer tous les services"
    echo "  -i, --infra         Déployer uniquement l'infrastructure"
    echo "  -m, --monitoring    Déployer uniquement le monitoring"
    echo ""
    echo "Exemples:"
    echo "  $0 backend-gestion v1.0.0    # Déployer backend-gestion avec le tag v1.0.0"
    echo "  $0 --all                      # Déployer tous les services"
    echo "  $0 --infra                    # Déployer l'infrastructure de base"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi

    if [ ! -d "$DEPLOY_PATH" ]; then
        log_error "Le répertoire de déploiement n'existe pas: $DEPLOY_PATH"
        exit 1
    fi

    log_info "Prérequis OK"
}

# Fonction pour pull les images
pull_images() {
    local service="${1:-}"

    cd "$DEPLOY_PATH"

    if [ -n "$service" ]; then
        log_info "Pull de l'image pour $service..."
        docker-compose $COMPOSE_FILES pull "$service"
    else
        log_info "Pull de toutes les images..."
        docker-compose $COMPOSE_FILES pull
    fi
}

# Fonction pour déployer un service spécifique
deploy_service() {
    local service="$1"
    local tag="${2:-latest}"

    cd "$DEPLOY_PATH"

    log_info "Déploiement de $service avec le tag $tag..."

    # Mettre à jour l'image dans le fichier .env si nécessaire
    if [ -f ".env" ]; then
        # Créer une backup
        cp .env .env.backup
    fi

    # Arrêter et redémarrer le service
    docker-compose $COMPOSE_FILES stop "$service" || true
    docker-compose $COMPOSE_FILES rm -f "$service" || true
    docker-compose $COMPOSE_FILES up -d "$service"

    log_info "Service $service déployé avec succès"
}

# Fonction pour déployer l'infrastructure
deploy_infra() {
    cd "$DEPLOY_PATH"

    log_info "Déploiement de l'infrastructure..."

    docker-compose -f docker-compose.yml pull
    docker-compose -f docker-compose.yml up -d

    log_info "Infrastructure déployée avec succès"
}

# Fonction pour déployer le monitoring
deploy_monitoring() {
    cd "$DEPLOY_PATH"

    log_info "Déploiement du monitoring..."

    docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml pull
    docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

    log_info "Monitoring déployé avec succès"
}

# Fonction pour déployer tous les services
deploy_all() {
    cd "$DEPLOY_PATH"

    log_info "Déploiement de tous les services..."

    docker-compose $COMPOSE_FILES pull
    docker-compose $COMPOSE_FILES up -d

    log_info "Tous les services déployés avec succès"
}

# Fonction pour nettoyer les anciennes images
cleanup() {
    log_info "Nettoyage des anciennes images..."
    docker image prune -f
    log_info "Nettoyage terminé"
}

# Fonction principale
main() {
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        -a|--all)
            check_prerequisites
            deploy_all
            cleanup
            ;;
        -i|--infra)
            check_prerequisites
            deploy_infra
            cleanup
            ;;
        -m|--monitoring)
            check_prerequisites
            deploy_monitoring
            cleanup
            ;;
        "")
            usage
            exit 1
            ;;
        *)
            local service="$1"
            local tag="${2:-latest}"
            check_prerequisites
            pull_images "$service"
            deploy_service "$service" "$tag"
            cleanup
            ;;
    esac
}

main "$@"
