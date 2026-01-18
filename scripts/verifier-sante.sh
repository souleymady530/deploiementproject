#!/bin/bash
# =============================================================================
# Script de vérification de santé des services
# Usage: ./verifier-sante.sh [service_name]
# =============================================================================

set -euo pipefail

# Configuration
DEPLOY_PATH="${DEPLOY_PATH:-/opt/apps/deploiementproject}"
MAX_RETRIES=30
RETRY_INTERVAL=2

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Vérifier PostgreSQL
check_postgres() {
    log_info "Vérification de PostgreSQL..."

    if docker exec postgres-db pg_isready -U postgres > /dev/null 2>&1; then
        log_success "PostgreSQL est opérationnel"
        return 0
    else
        log_fail "PostgreSQL n'est pas accessible"
        return 1
    fi
}

# Vérifier Prometheus
check_prometheus() {
    local port="${PROMETHEUS_PORT:-9190}"
    log_info "Vérification de Prometheus..."

    if curl -sf "http://localhost:${port}/-/healthy" > /dev/null 2>&1; then
        log_success "Prometheus est opérationnel"
        return 0
    else
        log_fail "Prometheus n'est pas accessible"
        return 1
    fi
}

# Vérifier Grafana
check_grafana() {
    local port="${GRAFANA_PORT:-3000}"
    log_info "Vérification de Grafana..."

    if curl -sf "http://localhost:${port}/api/health" > /dev/null 2>&1; then
        log_success "Grafana est opérationnel"
        return 0
    else
        log_fail "Grafana n'est pas accessible"
        return 1
    fi
}

# Vérifier Loki
check_loki() {
    local port="${LOKI_PORT:-3100}"
    log_info "Vérification de Loki..."

    if curl -sf "http://localhost:${port}/ready" > /dev/null 2>&1; then
        log_success "Loki est opérationnel"
        return 0
    else
        log_fail "Loki n'est pas accessible"
        return 1
    fi
}

# Vérifier un backend Spring Boot
check_spring_boot_backend() {
    local service_name="$1"
    local port="$2"

    log_info "Vérification de $service_name..."

    # Essayer /actuator/health d'abord, puis /health
    if curl -sf "http://localhost:${port}/actuator/health" > /dev/null 2>&1; then
        log_success "$service_name est opérationnel (actuator)"
        return 0
    elif curl -sf "http://localhost:${port}/health" > /dev/null 2>&1; then
        log_success "$service_name est opérationnel"
        return 0
    else
        log_fail "$service_name n'est pas accessible"
        return 1
    fi
}

# Vérifier un frontend
check_frontend() {
    local service_name="$1"
    local port="$2"

    log_info "Vérification de $service_name..."

    if curl -sf "http://localhost:${port}/" > /dev/null 2>&1; then
        log_success "$service_name est opérationnel"
        return 0
    else
        log_fail "$service_name n'est pas accessible"
        return 1
    fi
}

# Vérifier avec retry
check_with_retry() {
    local check_function="$1"
    shift
    local args=("$@")

    for i in $(seq 1 $MAX_RETRIES); do
        if $check_function "${args[@]}"; then
            return 0
        fi

        if [ $i -lt $MAX_RETRIES ]; then
            log_warn "Tentative $i/$MAX_RETRIES échouée, nouvelle tentative dans ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
    done

    return 1
}

# Vérifier tous les services d'infrastructure
check_infrastructure() {
    local failed=0

    echo ""
    echo "======================================"
    echo "  Vérification de l'infrastructure"
    echo "======================================"
    echo ""

    check_with_retry check_postgres || ((failed++))

    echo ""
    return $failed
}

# Vérifier le monitoring
check_monitoring() {
    local failed=0

    echo ""
    echo "======================================"
    echo "  Vérification du monitoring"
    echo "======================================"
    echo ""

    check_with_retry check_prometheus || ((failed++))
    check_with_retry check_grafana || ((failed++))
    check_with_retry check_loki || ((failed++))

    echo ""
    return $failed
}

# Vérifier les applications
check_applications() {
    local failed=0

    echo ""
    echo "======================================"
    echo "  Vérification des applications"
    echo "======================================"
    echo ""

    # Backend Gestion (port 8081)
    if docker ps --format '{{.Names}}' | grep -q "backend-gestion"; then
        check_with_retry check_spring_boot_backend "backend-gestion" "8081" || ((failed++))
    else
        log_warn "backend-gestion n'est pas démarré"
    fi

    # Backend NordText (port 8082)
    if docker ps --format '{{.Names}}' | grep -q "backend-nordtext"; then
        check_with_retry check_spring_boot_backend "backend-nordtext" "8082" || ((failed++))
    else
        log_warn "backend-nordtext n'est pas démarré"
    fi

    # Backend SGMAO (port 8083)
    if docker ps --format '{{.Names}}' | grep -q "backend-sgmao"; then
        check_with_retry check_spring_boot_backend "backend-sgmao" "8083" || ((failed++))
    else
        log_warn "backend-sgmao n'est pas démarré"
    fi

    # Frontend (port 80)
    if docker ps --format '{{.Names}}' | grep -q "frontend"; then
        check_with_retry check_frontend "frontend" "80" || ((failed++))
    else
        log_warn "frontend n'est pas démarré"
    fi

    echo ""
    return $failed
}

# Afficher le statut des conteneurs
show_container_status() {
    echo ""
    echo "======================================"
    echo "  Statut des conteneurs"
    echo "======================================"
    echo ""

    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

    echo ""
}

# Fonction principale
main() {
    local total_failed=0
    local check_type="${1:-all}"

    case "$check_type" in
        infra|infrastructure)
            check_infrastructure || ((total_failed++))
            ;;
        monitoring)
            check_monitoring || ((total_failed++))
            ;;
        apps|applications)
            check_applications || ((total_failed++))
            ;;
        all|"")
            check_infrastructure || ((total_failed++))
            check_monitoring || ((total_failed++))
            check_applications || ((total_failed++))
            ;;
        status)
            show_container_status
            exit 0
            ;;
        *)
            echo "Usage: $0 [infra|monitoring|apps|all|status]"
            exit 1
            ;;
    esac

    show_container_status

    echo "======================================"
    if [ $total_failed -eq 0 ]; then
        log_success "Toutes les vérifications sont passées!"
        exit 0
    else
        log_error "$total_failed groupe(s) de vérification ont échoué"
        exit 1
    fi
}

main "$@"
