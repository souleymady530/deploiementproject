# =============================================================================
# Dockerfile Multi-Stage pour Backend Spring Boot
# =============================================================================
# Copiez ce fichier a la racine de votre repo backend
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Copier les fichiers de configuration Maven
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .

# Telecharger les dependances (cache layer)
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copier le code source
COPY src ./src

# Build de l'application
RUN ./mvnw package -DskipTests -B

# Extraire les layers Spring Boot pour optimiser le cache
RUN java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# -----------------------------------------------------------------------------
# Stage 2: Runtime
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine AS runtime

# Creer un utilisateur non-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copier les layers Spring Boot dans l'ordre optimal pour le cache
COPY --from=builder /app/target/extracted/dependencies/ ./
COPY --from=builder /app/target/extracted/spring-boot-loader/ ./
COPY --from=builder /app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder /app/target/extracted/application/ ./

# Changer le proprietaire des fichiers
RUN chown -R appuser:appgroup /app

# Utiliser l'utilisateur non-root
USER appuser

# Exposer le port de l'application
EXPOSE 8080

# Variables d'environnement par defaut
ENV JAVA_OPTS="-Xms256m -Xmx512m" \
    SPRING_PROFILES_ACTIVE=prod

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Point d'entree avec les options JVM
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
