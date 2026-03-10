#!/bin/bash
# =============================================================================
# Script : Smoke Tests post-déploiement
# Usage  : bash smoke-tests.sh <K8S_IP> <NAMESPACE> <APP_NAME>
# =============================================================================

set -uo pipefail

K8S_IP="${1:-192.168.43.109}"
NAMESPACE="${2:-production}"
APP_NAME="${3:-java-app}"
APP_PORT="30080"
APP_URL="http://${K8S_IP}:${APP_PORT}"
MAX_RETRIES=10
WAIT_SECONDS=15

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()   { echo -e "${GREEN}[✅ PASS]${NC} $1"; }
fail()  { echo -e "${RED}[❌ FAIL]${NC} $1"; exit 1; }
info()  { echo -e "${YELLOW}[ℹ️  INFO]${NC} $1"; }

echo "================================================================"
echo "  🧪 SMOKE TESTS — ${APP_NAME}"
echo "  URL : ${APP_URL}"
echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"

# ── Test 1 : Health Check ─────────────────────────────────────────────────────
info "Test 1/4 : Health Check (/actuator/health)"
for i in $(seq 1 $MAX_RETRIES); do
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 --max-time 10 \
        "${APP_URL}/actuator/health" 2>/dev/null || echo "000")

    if [ "${HTTP_CODE}" = "200" ]; then
        log "Health check OK (HTTP ${HTTP_CODE}) — tentative ${i}/${MAX_RETRIES}"
        break
    fi

    if [ "${i}" -eq "${MAX_RETRIES}" ]; then
        fail "Health check échoué après ${MAX_RETRIES} tentatives (dernier code: ${HTTP_CODE})"
    fi
    info "Tentative ${i}/${MAX_RETRIES} — HTTP ${HTTP_CODE} — attente ${WAIT_SECONDS}s..."
    sleep $WAIT_SECONDS
done

# ── Test 2 : Readiness ────────────────────────────────────────────────────────
info "Test 2/4 : Readiness (/actuator/health/readiness)"
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    "${APP_URL}/actuator/health/readiness" 2>/dev/null || echo "000")

[ "${HTTP_CODE}" = "200" ] && \
    log "Readiness OK (HTTP ${HTTP_CODE})" || \
    fail "Readiness probe échouée (HTTP ${HTTP_CODE})"

# ── Test 3 : Endpoint principal ───────────────────────────────────────────────
info "Test 3/4 : Endpoint principal (/api/v1/status)"
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    "${APP_URL}/api/v1/status" 2>/dev/null || echo "000")

if [ "${HTTP_CODE}" = "200" ] || [ "${HTTP_CODE}" = "404" ]; then
    log "Endpoint API accessible (HTTP ${HTTP_CODE})"
else
    fail "Endpoint API inaccessible (HTTP ${HTTP_CODE})"
fi

# ── Test 4 : Métriques Prometheus ────────────────────────────────────────────
info "Test 4/4 : Métriques Prometheus (/actuator/prometheus)"
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    "${APP_URL}/actuator/prometheus" 2>/dev/null || echo "000")

[ "${HTTP_CODE}" = "200" ] && \
    log "Métriques Prometheus exposées (HTTP ${HTTP_CODE})" || \
    info "⚠️ Métriques non exposées (HTTP ${HTTP_CODE}) — vérifier MANAGEMENT_ENDPOINTS config"

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo "================================================================"
echo -e "  ${GREEN}✅ SMOKE TESTS RÉUSSIS${NC}"
echo "  Application : ${APP_URL}"
echo "  Namespace   : ${NAMESPACE}"
echo "  Date        : $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"
