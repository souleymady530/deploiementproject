# =============================================================================
# Dockerfile Multi-Stage pour Frontend Angular
# =============================================================================
# Copiez ce fichier a la racine de votre repo frontend
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build Angular Application
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

# Copier les fichiers de dependances
COPY package*.json ./

# Installer les dependances
RUN npm ci

# Copier le code source
COPY . .

# Arguments de build
ARG API_URL=http://localhost:8081
ENV API_URL=$API_URL

# Build de l'application Angular en mode production
RUN npm run build -- --configuration=production

# -----------------------------------------------------------------------------
# Stage 2: Nginx Server
# -----------------------------------------------------------------------------
FROM nginx:alpine AS runtime

# Copier la configuration Nginx personnalisee
COPY nginx.conf /etc/nginx/nginx.conf

# Copier les fichiers build depuis le stage builder
# Adapter le chemin selon le nom de votre projet Angular
COPY --from=builder /app/dist/*/browser /usr/share/nginx/html

# Creer un utilisateur non-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid && \
    chown -R appuser:appgroup /usr/share/nginx/html

# Exposer le port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

# Demarrer Nginx en mode foreground
CMD ["nginx", "-g", "daemon off;"]
