FROM eclipse-temurin:17-jre-alpine AS runtime

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}"          \
      org.opencontainers.image.revision="${VCS_REF}"            \
      org.opencontainers.image.version="${VERSION}"             \
      org.opencontainers.image.title="java-app"                 \
      org.opencontainers.image.description="Application Java Spring Boot" \
      org.opencontainers.image.vendor="MyOrg"                   \
      org.opencontainers.image.source="https://github.com/lms-30/deployer_app_java"

RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache curl tzdata && \
    rm -rf /var/cache/apk/* /tmp/*

ENV TZ=Indian/Antananarivo
RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

RUN addgroup -S appgroup && \
    adduser  -S appuser -G appgroup -u 1000 -h /app -s /sbin/nologin

WORKDIR /app

COPY --chown=appuser:appgroup target/*.jar app.jar

RUN mkdir -p /app/logs /app/tmp && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

ENV SPRING_PROFILES_ACTIVE=production                                        \
    SERVER_PORT=8080                                                         \
    JAVA_OPTS=""                                                             \
    MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,prometheus,metrics \
    MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS=always                           \
    MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED=true

HEALTHCHECK \
    --interval=30s \
    --timeout=10s  \
    --start-period=60s \
    --retries=3 \
    CMD curl -sf http://localhost:8080/actuator/health | \
        grep -q '"status":"UP"' || exit 1

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
