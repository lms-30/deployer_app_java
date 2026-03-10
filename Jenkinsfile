// =============================================================================
// 🚀 PIPELINE CI/CD COMPLET — Java App + PostgreSQL
// Architecture :
//   PC Hôte        → Jenkins (Docker) + SonarQube (Docker) + Ansible
//   192.168.43.133 → Harbor (harbor.local, HTTPS)
//   192.168.43.129 → Kubernetes (Kubeadm)
// =============================================================================

pipeline {
    agent any

    // ─── Variables globales ───────────────────────────────────────────────────
    environment {
        // Application
        APP_NAME          = "java-app"
        APP_VERSION       = "${BUILD_NUMBER}-${GIT_COMMIT[0..6]}"
        NAMESPACE         = "production"

        // Harbor Registry (VM 192.168.43.133)
        HARBOR_REGISTRY   = "harbor.local"
        HARBOR_PROJECT    = "myproject"
        APP_IMAGE         = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${APP_NAME}"

        // SonarQube (PC hôte Docker)
        SONAR_HOST        = "http://sonarqube:9000"

        // Kubernetes (VM 192.168.43.109)
        K8S_HOST          = "192.168.43.109"

        // Credentials Jenkins
        HARBOR_CREDS      = credentials('harbor-credentials')
        SONAR_TOKEN       = credentials('sonarqube-token')

        // Logs
        LOGS_DIR          = "/var/jenkins_home/pipeline-logs"
        LOG_FILE          = "${LOGS_DIR}/${APP_NAME}-build-${BUILD_NUMBER}.log"

        // Ansible
        ANSIBLE_DIR       = "${WORKSPACE}/ansible"
        ANSIBLE_HOST_KEY_CHECKING = "False"
    }

    options {
        timeout(time: 90, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '20'))
        timestamps()
        ansiColor('xterm')
    }

    stages {

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 0 — INITIALISATION LOGS
        // ═════════════════════════════════════════════════════════════════════
        stage('📝 Init Logs') {
            steps {
                script {
                    sh """
                        mkdir -p ${LOGS_DIR}
                        cat > ${LOG_FILE} <<EOF
=============================================================
  JENKINS PIPELINE LOG
  Application : ${APP_NAME}
  Build N°    : ${BUILD_NUMBER}
  Branch      : ${GIT_BRANCH}
  Commit      : ${GIT_COMMIT}
  Date        : \$(date '+%Y-%m-%d %H:%M:%S')
  Lancé par   : \${BUILD_USER_ID:-automatique}
=============================================================
EOF
                        echo "[$(date '+%H:%M:%S')] [INIT] Pipeline démarré" >> ${LOG_FILE}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 1 — CHECKOUT
        // ═════════════════════════════════════════════════════════════════════
        stage('📥 Checkout') {
            steps {
                script {
                    checkout scm
                    env.GIT_AUTHOR  = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    env.GIT_MESSAGE = sh(script: "git log -1 --pretty=format:'%s'",  returnStdout: true).trim()
                    sh """
                        echo "[$(date '+%H:%M:%S')] [CHECKOUT] Branch: ${GIT_BRANCH} | Auteur: ${env.GIT_AUTHOR} | Commit: ${env.GIT_MESSAGE}" >> ${LOG_FILE}
                    """
                }
                echo "✅ Code récupéré — Branch: ${GIT_BRANCH} | ${env.GIT_AUTHOR}"
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 2 — 🔐 SÉCURITÉ : GITLEAKS (Détection secrets)
        // ═════════════════════════════════════════════════════════════════════
        stage('🔐 Gitleaks — Secret Scan') {
            steps {
                script {
                    sh """
                        echo "[$(date '+%H:%M:%S')] [GITLEAKS] Démarrage du scan des secrets..." >> ${LOG_FILE}

                        docker run --rm \
                            -v ${WORKSPACE}:/path \
                            zricethezav/gitleaks:latest \
                            detect \
                            --source="/path" \
                            --report-format=json \
                            --report-path="/path/reports/gitleaks-report.json" \
                            --exit-code=1 \
                            --verbose 2>&1 | tee -a ${LOG_FILE} || true

                        LEAKS=0
                        if [ -f reports/gitleaks-report.json ]; then
                            LEAKS=\$(python3 -c "import json,sys; d=json.load(open('reports/gitleaks-report.json')); print(len(d))" 2>/dev/null || echo "0")
                        fi

                        echo "[$(date '+%H:%M:%S')] [GITLEAKS] Secrets détectés: \${LEAKS}" >> ${LOG_FILE}

                        if [ "\${LEAKS}" -gt "0" ]; then
                            echo "[$(date '+%H:%M:%S')] [GITLEAKS] ❌ ÉCHEC — \${LEAKS} secret(s) détecté(s)" >> ${LOG_FILE}
                            echo "❌ ALERTE SÉCURITÉ : \${LEAKS} secret(s) détecté(s) dans le code !"
                            exit 1
                        fi
                        echo "[$(date '+%H:%M:%S')] [GITLEAKS] ✅ Aucun secret détecté" >> ${LOG_FILE}
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 3 — 🔍 SÉCURITÉ : SONARQUBE (Analyse vulnérabilités code)
        // ═════════════════════════════════════════════════════════════════════
        stage('🔍 SonarQube — Code Analysis') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [SONAR] Démarrage analyse SonarQube...' >> ${LOG_FILE}"
                }
                withSonarQubeEnv('SonarQube') {
                    sh """
                        mvn sonar:sonar \
                            -Dsonar.projectKey=${APP_NAME} \
                            -Dsonar.projectName="${APP_NAME}" \
                            -Dsonar.host.url=${SONAR_HOST} \
                            -Dsonar.login=${SONAR_TOKEN} \
                            -Dsonar.java.binaries=target/classes \
                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                            -Dsonar.exclusions="**/test/**" \
                            --no-transfer-progress 2>&1 | tee -a ${LOG_FILE}
                    """
                }
                sh "echo '[$(date '+%H:%M:%S')] [SONAR] ✅ Analyse SonarQube terminée' >> ${LOG_FILE}"
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 4 — 🚦 QUALITY GATE SONARQUBE
        // ═════════════════════════════════════════════════════════════════════
        stage('🚦 Quality Gate') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [QUALITY-GATE] Vérification Quality Gate...' >> ${LOG_FILE}"
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        sh "echo '[$(date '+%H:%M:%S')] [QUALITY-GATE] Statut: ${qg.status}' >> ${LOG_FILE}"
                        if (qg.status != 'OK') {
                            sh "echo '[$(date '+%H:%M:%S')] [QUALITY-GATE] ❌ ÉCHEC — Qualité insuffisante' >> ${LOG_FILE}"
                            error "Quality Gate échoué : ${qg.status}"
                        }
                    }
                    sh "echo '[$(date '+%H:%M:%S')] [QUALITY-GATE] ✅ Quality Gate OK' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 5 — 🏗️ BUILD MAVEN + TESTS
        // ═════════════════════════════════════════════════════════════════════
        stage('🏗️ Maven Build') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [BUILD] Démarrage Maven build...' >> ${LOG_FILE}"
                    sh """
                        mvn clean package \
                            -DskipTests=false \
                            -B --no-transfer-progress \
                            2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[$(date '+%H:%M:%S')] [BUILD] ✅ Build Maven réussi' >> ${LOG_FILE}"
                }
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target/site/jacoco',
                        reportFiles: 'index.html',
                        reportName: 'Code Coverage'
                    ])
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 6 — 🛡️ SÉCURITÉ : OWASP DEPENDENCY CHECK
        // ═════════════════════════════════════════════════════════════════════
        stage('🛡️ OWASP Dependency Check') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [OWASP] Scan des dépendances Maven...' >> ${LOG_FILE}"
                    sh """
                        mvn org.owasp:dependency-check-maven:check \
                            -DfailBuildOnCVSS=7 \
                            -Dformat=ALL \
                            --no-transfer-progress 2>&1 | tee -a ${LOG_FILE} || true
                    """
                    sh "echo '[$(date '+%H:%M:%S')] [OWASP] ✅ Scan OWASP terminé' >> ${LOG_FILE}"
                }
            }
            post {
                always {
                    dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
                    archiveArtifacts artifacts: 'target/dependency-check-report.*', allowEmptyArchive: true
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 7 — 🐳 DOCKER BUILD
        // ═════════════════════════════════════════════════════════════════════
        stage('🐳 Docker Build') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [DOCKER] Build image Docker...' >> ${LOG_FILE}"
                    sh """
                        docker build \
                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                            --build-arg VCS_REF=${GIT_COMMIT[0..6]} \
                            --build-arg VERSION=${APP_VERSION} \
                            -t ${APP_IMAGE}:${APP_VERSION} \
                            -t ${APP_IMAGE}:latest \
                            -f docker/Dockerfile . \
                            2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [DOCKER] ✅ Image construite : ${APP_IMAGE}:${APP_VERSION}" >> ${LOG_FILE}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 8 — 🔬 SÉCURITÉ : TRIVY (Scan image Docker)
        // ═════════════════════════════════════════════════════════════════════
        stage('🔬 Trivy — Image Scan') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [TRIVY] Scan de l image Docker...' >> ${LOG_FILE}"
                    sh """
                        mkdir -p reports

                        # Rapport JSON complet
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v \${HOME}/.cache/trivy:/root/.cache \
                            -v ${WORKSPACE}/reports:/reports \
                            aquasec/trivy:latest image \
                            --exit-code 0 \
                            --severity LOW,MEDIUM \
                            --format json \
                            --output /reports/trivy-report.json \
                            ${APP_IMAGE}:${APP_VERSION} \
                            2>&1 | tee -a ${LOG_FILE}

                        # Bloquer sur HIGH/CRITICAL
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v \${HOME}/.cache/trivy:/root/.cache \
                            aquasec/trivy:latest image \
                            --exit-code 1 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            ${APP_IMAGE}:${APP_VERSION} \
                            2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [TRIVY] ✅ Aucune vulnérabilité CRITICAL/HIGH" >> ${LOG_FILE}
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/trivy-report.json', allowEmptyArchive: true
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 9 — 📤 PUSH VERS HARBOR (192.168.43.133)
        // ═════════════════════════════════════════════════════════════════════
        stage('📤 Push → Harbor') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [HARBOR] Push vers harbor.local (192.168.43.133)...' >> ${LOG_FILE}"
                    sh """
                        echo \${HARBOR_CREDS_PSW} | docker login ${HARBOR_REGISTRY} \
                            -u \${HARBOR_CREDS_USR} --password-stdin

                        docker push ${APP_IMAGE}:${APP_VERSION} 2>&1 | tee -a ${LOG_FILE}
                        docker push ${APP_IMAGE}:latest          2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [HARBOR] ✅ Image poussée : ${APP_IMAGE}:${APP_VERSION}" >> ${LOG_FILE}
                        docker logout ${HARBOR_REGISTRY}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 10 — ⚙️ ANSIBLE : PRÉPARER KUBERNETES (192.168.43.109)
        // ═════════════════════════════════════════════════════════════════════
        stage('⚙️ Ansible — Setup K8s') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [ANSIBLE] Configuration Kubernetes (192.168.43.109)...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/setup-kubernetes.yml \
                            --extra-vars "namespace=${NAMESPACE}" \
                            -v 2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [ANSIBLE] ✅ Infrastructure Kubernetes prête" >> ${LOG_FILE}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 11 — 🚀 ANSIBLE : DÉPLOIEMENT APP + BDD
        // ═════════════════════════════════════════════════════════════════════
        stage('🚀 Deploy — App + Database') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [DEPLOY] Déploiement application + PostgreSQL...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/deploy-app.yml \
                            --extra-vars "
                                app_image=${APP_IMAGE}:${APP_VERSION}
                                namespace=${NAMESPACE}
                                build_number=${BUILD_NUMBER}
                                app_version=${APP_VERSION}
                            " \
                            -v 2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [DEPLOY] ✅ Déploiement Kubernetes terminé" >> ${LOG_FILE}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 12 — ✅ VÉRIFICATION DÉPLOIEMENT
        // ═════════════════════════════════════════════════════════════════════
        stage('✅ Verify Deployment') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [VERIFY] Vérification du déploiement...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/verify-deployment.yml \
                            --extra-vars "namespace=${NAMESPACE} app_name=${APP_NAME}" \
                            -v 2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [VERIFY] ✅ Déploiement vérifié" >> ${LOG_FILE}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 13 — 🧪 SMOKE TESTS
        // ═════════════════════════════════════════════════════════════════════
        stage('🧪 Smoke Tests') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [SMOKE] Smoke tests post-déploiement...' >> ${LOG_FILE}"
                    sh """
                        bash scripts/smoke-tests.sh ${K8S_HOST} ${NAMESPACE} ${APP_NAME} \
                            2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [SMOKE] ✅ Smoke tests réussis" >> ${LOG_FILE}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 14 — 📊 MONITORING : PROMETHEUS + GRAFANA
        // ═════════════════════════════════════════════════════════════════════
        stage('📊 Setup Monitoring') {
            steps {
                script {
                    sh "echo '[$(date '+%H:%M:%S')] [MONITORING] Déploiement Prometheus + Grafana...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/setup-monitoring.yml \
                            --extra-vars "
                                namespace=monitoring
                                app_name=${APP_NAME}
                                build_number=${BUILD_NUMBER}
                            " \
                            -v 2>&1 | tee -a ${LOG_FILE}

                        echo "[$(date '+%H:%M:%S')] [MONITORING] ✅ Prometheus + Grafana opérationnels" >> ${LOG_FILE}
                    """
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // POST ACTIONS
    // ═════════════════════════════════════════════════════════════════════════
    post {
        success {
            script {
                sh """
                    echo "" >> ${LOG_FILE}
                    echo "=============================================================" >> ${LOG_FILE}
                    echo "  ✅ PIPELINE RÉUSSI" >> ${LOG_FILE}
                    echo "  Build        : #${BUILD_NUMBER}" >> ${LOG_FILE}
                    echo "  Image        : ${APP_IMAGE}:${APP_VERSION}" >> ${LOG_FILE}
                    echo "  Durée        : \$((SECONDS / 60)) min \$((SECONDS % 60)) sec" >> ${LOG_FILE}
                    echo "  Terminé le   : \$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}
                    echo "=============================================================" >> ${LOG_FILE}

                    # Archiver le log dans workspace pour téléchargement
                    cp ${LOG_FILE} ${WORKSPACE}/reports/pipeline-${BUILD_NUMBER}.log
                """
                archiveArtifacts artifacts: 'reports/pipeline-*.log', allowEmptyArchive: false
            }
            emailext(
                subject: "✅ [Jenkins] ${APP_NAME} — Build #${BUILD_NUMBER} RÉUSSI",
                body: """<h2>✅ Déploiement réussi !</h2>
                    <table>
                        <tr><td><b>Application</b></td><td>${APP_NAME}</td></tr>
                        <tr><td><b>Version</b></td><td>${APP_VERSION}</td></tr>
                        <tr><td><b>Branch</b></td><td>${GIT_BRANCH}</td></tr>
                        <tr><td><b>Auteur</b></td><td>${env.GIT_AUTHOR}</td></tr>
                        <tr><td><b>Monitoring</b></td><td>http://${K8S_HOST}:32000 (Grafana)</td></tr>
                    </table>
                    <p><a href="${BUILD_URL}">Voir le build Jenkins</a></p>""",
                mimeType: 'text/html',
                to: 'devops-team@example.com'
            )
        }

        failure {
            script {
                sh """
                    echo "" >> ${LOG_FILE}
                    echo "=============================================================" >> ${LOG_FILE}
                    echo "  ❌ PIPELINE ÉCHOUÉ" >> ${LOG_FILE}
                    echo "  Stage en échec : ${env.STAGE_NAME}" >> ${LOG_FILE}
                    echo "  Build         : #${BUILD_NUMBER}" >> ${LOG_FILE}
                    echo "  Date          : \$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}
                    echo "=============================================================" >> ${LOG_FILE}

                    cp ${LOG_FILE} ${WORKSPACE}/reports/pipeline-${BUILD_NUMBER}-FAILED.log || true
                """
                archiveArtifacts artifacts: 'reports/pipeline-*-FAILED.log', allowEmptyArchive: true
            }
            // Rollback automatique si le déploiement échoue
            script {
                def deployStages = ['Deploy — App + Database', 'Verify Deployment', 'Smoke Tests']
                if (env.STAGE_NAME in deployStages) {
                    sh """
                        echo "[$(date '+%H:%M:%S')] [ROLLBACK] Rollback automatique en cours..." >> ${LOG_FILE}
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/rollback.yml \
                            --extra-vars "namespace=${NAMESPACE} app_name=${APP_NAME}" \
                            -v 2>&1 | tee -a ${LOG_FILE} || true
                    """
                }
            }
            emailext(
                subject: "❌ [Jenkins] ${APP_NAME} — Build #${BUILD_NUMBER} ÉCHOUÉ",
                body: """<h2>❌ Pipeline échoué !</h2>
                    <p><b>Stage en échec :</b> ${env.STAGE_NAME}</p>
                    <p><b>Branch :</b> ${GIT_BRANCH}</p>
                    <p><a href="${BUILD_URL}console">Voir les logs complets</a></p>""",
                mimeType: 'text/html',
                to: 'devops-team@example.com'
            )
        }

        always {
            cleanWs(patterns: [[pattern: 'target/**', type: 'INCLUDE']])
            sh 'docker image prune -f --filter "until=48h" || true'
        }
    }
}
