# =============================================================================
# Dockerfile — Application Java Spring Boot
# Multi-stage build : image finale minimale et sécurisée
# Base : Eclipse Temurin JDK 17 (Alpine)
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# STAGE 1 — DÉPENDANCES (cache Maven)
# But : télécharger les dépendances séparément pour profiter du cache Docker
# ─────────────────────────────────────────────────────────────────────────────
FROM maven:3.9.6-eclipse-temurin-17-alpine AS dependencies

WORKDIR /app

# Copier uniquement le pom.xml pour cacher les dépendances
COPY pom.xml .
RUN mvn dependency:go-offline \
        -B \
        --no-transfer-progress \
        -q

# ─────────────────────────────────────────────────────────────────────────────
# STAGE 2 — BUILD & TESTS
# But : compiler le code et exécuter les tests unitaires
# ─────────────────────────────────────────────────────────────────────────────
FROM dependencies AS builder

WORKDIR /app

# Copier le code source
COPY src ./src

# Compiler et tester
RUN mvn clean package \
        -B \
        --no-transfer-progress \
        -Dmaven.test.failure.ignore=false \
    && echo "✅ Build réussi : $(ls target/*.jar)"

# ─────────────────────────────────────────────────────────────────────────────
# STAGE 3 — RUNTIME (image finale minimale)
# But : image de production légère, sans Maven ni JDK complet
# ─────────────────────────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine AS runtime

# ── Métadonnées OCI ───────────────────────────────────────────────────────────
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}"          \
      org.opencontainers.image.revision="${VCS_REF}"            \
      org.opencontainers.image.version="${VERSION}"             \
      org.opencontainers.image.title="java-app"                 \
      org.opencontainers.image.description="Application Java Spring Boot" \
      org.opencontainers.image.vendor="MyOrg"                   \
      org.opencontainers.image.source="https://github.com/myorg/java-app"

# ── Sécurité : mise à jour des paquets Alpine ─────────────────────────────────
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
        curl \
        tzdata && \
    rm -rf /var/cache/apk/* /tmp/*

# ── Timezone ──────────────────────────────────────────────────────────────────
ENV TZ=Afrique/Antananarivo
RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

# ── Créer un utilisateur non-root dédié ──────────────────────────────────────
RUN addgroup -S appgroup && \
    adduser  -S appuser -G appgroup -u 1000 -h /app -s /sbin/nologin

WORKDIR /app

# ── Copier le JAR depuis le stage builder ────────────────────────────────────
COPY --from=builder --chown=appuser:appgroup /app/target/*.jar app.jar

# ── Répertoires nécessaires avec les bons droits ─────────────────────────────
RUN mkdir -p /app/logs /app/tmp && \
    chown -R appuser:appgroup /app

# ── Switcher vers l'utilisateur non-root ─────────────────────────────────────
USER appuser

# ── Port exposé ───────────────────────────────────────────────────────────────
EXPOSE 8080

# ── Variables d'environnement par défaut ─────────────────────────────────────
ENV SPRING_PROFILES_ACTIVE=production          \
    SERVER_PORT=8080                           \
    JAVA_OPTS=""                               \
    # Expose les endpoints Actuator pour Prometheus + K8s probes
    MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,prometheus,metrics \
    MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS=always                           \
    MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED=true

# ── Health Check Docker (utilisé hors Kubernetes) ────────────────────────────
HEALTHCHECK \
    --interval=30s \
    --timeout=10s  \
    --start-period=60s \
    --retries=3 \
    CMD curl -sf http://localhost:8080/actuator/health | \
        grep -q '"status":"UP"' || exit 1

# ── Point d'entrée ────────────────────────────────────────────────────────────
# Options JVM optimisées pour conteneur :
#   UseContainerSupport  → respecte les limits Kubernetes (CPU/RAM)
#   MaxRAMPercentage     → utilise max 75% de la RAM allouée au conteneur
#   UseG1GC              → garbage collector adapté aux microservices
#   egd                  → entropie rapide pour éviter les délais au démarrage
ENTRYPOINT ["sh", "-c", \
    "exec java \
        -XX:+UseContainerSupport \
        -XX:MaxRAMPercentage=75.0 \
        -XX:InitialRAMPercentage=25.0 \
        -XX:+UseG1GC \
        -XX:+ExitOnOutOfMemoryError \
        -Djava.security.egd=file:/dev/./urandom \
        -Dfile.encoding=UTF-8 \
        -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE} \
        ${JAVA_OPTS} \
        -jar /app/app.jar"]
