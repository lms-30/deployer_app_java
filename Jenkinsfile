// =============================================================================
// 🚀 PIPELINE CI/CD COMPLET — Java App + PostgreSQL
// Architecture :
//   PC Hôte        → Jenkins (Docker) + SonarQube (Docker) + Ansible
//   192.168.43.133 → Harbor (harbor.local, HTTPS)
//   192.168.43.129 → Kubernetes (Kubeadm)
// =============================================================================

pipeline {
    agent any

    environment {
        APP_NAME          = "java-app"
        APP_VERSION       = "${BUILD_NUMBER}-${GIT_COMMIT[0..6]}"
        NAMESPACE         = "production"

        HARBOR_REGISTRY   = "harbor.local"
        HARBOR_PROJECT    = "myproject"
        APP_IMAGE         = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${APP_NAME}"

        SONAR_HOST        = "http://sonarqube:9000"
        K8S_HOST          = "192.168.43.129"

        HARBOR_CREDS      = credentials('harbor-credentials')
        SONAR_TOKEN       = credentials('sonarqube-token')

        LOGS_DIR          = "/var/jenkins_home/pipeline-logs"
        LOG_FILE          = "${LOGS_DIR}/${APP_NAME}-build-${BUILD_NUMBER}.log"

        ANSIBLE_DIR       = "${WORKSPACE}/ansible"
        ANSIBLE_HOST_KEY_CHECKING = "False"
        NVD_API_KEY = credentials('nvd-api-key')
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
        stage('Init Logs') {
            steps {
                script {
                    def buildUser = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')
                                    .collect { it.userId ?: 'automatique' }
                                    .join(', ') ?: 'automatique'
                    sh """
                        mkdir -p ${LOGS_DIR}
                        cat > ${LOG_FILE} <<'ENDOFFILE'
=============================================================
  JENKINS PIPELINE LOG
  Application : ${APP_NAME}
  Build N     : ${BUILD_NUMBER}
  Branch      : ${GIT_BRANCH}
  Date        : "\$(date '+%Y-%m-%d %H:%M:%S')" 
  Lance par   : ${buildUser}
=============================================================
ENDOFFILE
                        echo "[\$(date '+%H:%M:%S')] [INIT] Pipeline demarre" >> ${LOG_FILE}
                    """
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 1 — CHECKOUT
        // ═════════════════════════════════════════════════════════════════════
        stage('Checkout') {
            steps {
                script {
                    checkout scm
                    env.GIT_AUTHOR  = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    env.GIT_MESSAGE = sh(script: "git log -1 --pretty=format:'%s'",  returnStdout: true).trim()
                    sh "echo '[\$(date +%H:%M:%S)] [CHECKOUT] Branch: ${GIT_BRANCH} | Auteur: ${env.GIT_AUTHOR}' >> ${LOG_FILE}"
                }
                echo "Code recupere — Branch: ${GIT_BRANCH} | ${env.GIT_AUTHOR}"
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 2 — GITLEAKS
        // ═════════════════════════════════════════════════════════════════════
        stage('Gitleaks — Secret Scan') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [GITLEAKS] Demarrage scan secrets...' >> ${LOG_FILE}"
                    sh """
                        mkdir -p ${WORKSPACE}/reports

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
                            LEAKS=\$(python3 -c "import json; d=json.load(open('reports/gitleaks-report.json')); print(len(d))" 2>/dev/null || echo "0")
                        fi

                        echo "[\$(date +%H:%M:%S)] [GITLEAKS] Secrets detectes: \${LEAKS}" >> ${LOG_FILE}

                        if [ "\${LEAKS}" -gt "0" ]; then
                            echo "[\$(date +%H:%M:%S)] [GITLEAKS] ECHEC - \${LEAKS} secret(s) detecte(s)" >> ${LOG_FILE}
                            exit 1
                        fi
                        echo "[\$(date +%H:%M:%S)] [GITLEAKS] OK - Aucun secret detecte" >> ${LOG_FILE}
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
        // STAGE 3 — MAVEN BUILD
        // ═════════════════════════════════════════════════════════════════════
        stage('Maven Build') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [BUILD] Demarrage Maven build...' >> ${LOG_FILE}"
                    sh """
                        mvn clean package \
                            -DskipTests=false \
                            -B --no-transfer-progress \
                            2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [BUILD] OK - Build Maven reussi' >> ${LOG_FILE}"
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                    archiveArtifacts artifacts: 'target/site/jacoco/**', allowEmptyArchive: true
                }
            }
        }
 
        // ═════════════════════════════════════════════════════════════════════
        // STAGE 4 — SONARQUBE
        // ═════════════════════════════════════════════════════════════════════
        stage('SonarQube — Code Analysis') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [SONAR] Demarrage analyse SonarQube...' >> ${LOG_FILE}"
                }
                withSonarQubeEnv('SonarQube') {
                    sh """
                        mvn sonar:sonar \
                            -Dsonar.projectKey=${APP_NAME} \
                            -Dsonar.projectName="${APP_NAME}" \
                            -Dsonar.host.url=${SONAR_HOST} \
                            -Dsonar.login=${SONAR_TOKEN} \
                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                            -Dsonar.exclusions="**/test/**" \
                            --no-transfer-progress 2>&1 | tee -a ${LOG_FILE}
                    """
                }
                sh "echo '[\$(date +%H:%M:%S)] [SONAR] OK - Analyse terminee' >> ${LOG_FILE}"
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 5 — QUALITY GATE
        // ═════════════════════════════════════════════════════════════════════
        stage('Quality Gate') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [QUALITY-GATE] Verification...' >> ${LOG_FILE}"
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        sh "echo '[\$(date +%H:%M:%S)] [QUALITY-GATE] Statut: ${qg.status}' >> ${LOG_FILE}"
                        if (qg.status != 'OK') {
                            sh "echo '[\$(date +%H:%M:%S)] [QUALITY-GATE] ECHEC - Qualite insuffisante' >> ${LOG_FILE}"
                            error "Quality Gate echoue : ${qg.status}"
                        }
                    }
                    sh "echo '[\$(date +%H:%M:%S)] [QUALITY-GATE] OK' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 6 — OWASP
        // ═════════════════════════════════════════════════════════════════════
        stage('OWASP Dependency Check') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [OWASP] Scan dependances Maven...' >> ${LOG_FILE}"
                    sh """
                        mvn org.owasp:dependency-check-maven:check \
                            -DfailBuildOnCVSS=7 \
                            -Dformat=ALL \
                            -DnvdApiKey=${NVD_API_KEY} \
                             -DsuppressionFile=owasp-suppressions.xml \
                            --no-transfer-progress 2>&1 | tee -a ${LOG_FILE} || true
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [OWASP] OK - Scan termine' >> ${LOG_FILE}"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'target/dependency-check-report.*', allowEmptyArchive: true
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 7 — DOCKER BUILD
        // ═════════════════════════════════════════════════════════════════════
        stage('Docker Build') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [DOCKER] Build image Docker...' >> ${LOG_FILE}"
                    sh """
                        docker build \
                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                            --build-arg VCS_REF=${GIT_COMMIT[0..6]} \
                            --build-arg VERSION=${APP_VERSION} \
                            -t ${APP_IMAGE}:${APP_VERSION} \
                            -t ${APP_IMAGE}:latest \
                            -f docker/Dockerfile . \
                            2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [DOCKER] OK - Image construite : ${APP_IMAGE}:${APP_VERSION}' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 8 — TRIVY
        // ═════════════════════════════════════════════════════════════════════
        stage('Trivy — Image Scan') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [TRIVY] Scan image Docker...' >> ${LOG_FILE}"
                    sh """
                        mkdir -p reports

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

                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v \${HOME}/.cache/trivy:/root/.cache \
                            aquasec/trivy:latest image \
                            --exit-code 1 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            ${APP_IMAGE}:${APP_VERSION} \
                            2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [TRIVY] OK - Aucune vulnerabilite CRITICAL/HIGH' >> ${LOG_FILE}"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/trivy-report.json', allowEmptyArchive: true
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 9 — PUSH HARBOR
        // ═════════════════════════════════════════════════════════════════════
        stage('Push Harbor') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [HARBOR] Push vers harbor.local...' >> ${LOG_FILE}"
                    sh """
                        echo \${HARBOR_CREDS_PSW} | docker login ${HARBOR_REGISTRY} \
                            -u \${HARBOR_CREDS_USR} --password-stdin

                        docker push ${APP_IMAGE}:${APP_VERSION} 2>&1 | tee -a ${LOG_FILE}
                        docker push ${APP_IMAGE}:latest          2>&1 | tee -a ${LOG_FILE}

                        docker logout ${HARBOR_REGISTRY}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [HARBOR] OK - Image poussee : ${APP_IMAGE}:${APP_VERSION}' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 10 — ANSIBLE SETUP K8S
        // ═════════════════════════════════════════════════════════════════════
        stage('Ansible — Setup K8s') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [ANSIBLE] Configuration Kubernetes...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/setup-kubernetes.yml \
                            --extra-vars "namespace=${NAMESPACE}" \
                            -v 2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [ANSIBLE] OK - Infrastructure Kubernetes prete' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 11 — DEPLOY
        // ═════════════════════════════════════════════════════════════════════
        stage('Deploy — App + Database') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [DEPLOY] Deploiement application + PostgreSQL...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/deploy-app.yml \
                            --extra-vars "app_image=${APP_IMAGE}:${APP_VERSION} namespace=${NAMESPACE} build_number=${BUILD_NUMBER} app_version=${APP_VERSION}" \
                            -v 2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [DEPLOY] OK - Deploiement Kubernetes termine' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 12 — VERIFY
        // ═════════════════════════════════════════════════════════════════════
        stage('Verify Deployment') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [VERIFY] Verification deploiement...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/verify-deployment.yml \
                            --extra-vars "namespace=${NAMESPACE} app_name=${APP_NAME}" \
                            -v 2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [VERIFY] OK - Deploiement verifie' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 13 — SMOKE TESTS
        // ═════════════════════════════════════════════════════════════════════
        stage('Smoke Tests') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [SMOKE] Smoke tests post-deploiement...' >> ${LOG_FILE}"
                    sh """
                        bash scripts/smoke-tests.sh ${K8S_HOST} ${NAMESPACE} ${APP_NAME} \
                            2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [SMOKE] OK - Smoke tests reussis' >> ${LOG_FILE}"
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // STAGE 14 — MONITORING
        // ═════════════════════════════════════════════════════════════════════
        stage('Setup Monitoring') {
            steps {
                script {
                    sh "echo '[\$(date +%H:%M:%S)] [MONITORING] Deploiement Prometheus + Grafana...' >> ${LOG_FILE}"
                    sh """
                        cd ${ANSIBLE_DIR}
                        ansible-playbook \
                            -i inventory/hosts.yml \
                            playbooks/setup-monitoring.yml \
                            --extra-vars "namespace=monitoring app_name=${APP_NAME} build_number=${BUILD_NUMBER}" \
                            -v 2>&1 | tee -a ${LOG_FILE}
                    """
                    sh "echo '[\$(date +%H:%M:%S)] [MONITORING] OK - Prometheus + Grafana operationnels' >> ${LOG_FILE}"
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
                    echo "  OK PIPELINE REUSSI"                                          >> ${LOG_FILE}
                    echo "  Build   : #${BUILD_NUMBER}"                                  >> ${LOG_FILE}
                    echo "  Image   : ${APP_IMAGE}:${APP_VERSION}"                       >> ${LOG_FILE}
                    echo "  Termine : \$(date '+%Y-%m-%d %H:%M:%S')"                     >> ${LOG_FILE}
                    echo "=============================================================" >> ${LOG_FILE}
                    mkdir -p ${WORKSPACE}/reports
                    cp ${LOG_FILE} ${WORKSPACE}/reports/pipeline-${BUILD_NUMBER}.log
                """
                archiveArtifacts artifacts: 'reports/pipeline-*.log', allowEmptyArchive: false
            }
            emailext(
                subject: "[Jenkins] ${APP_NAME} — Build #${BUILD_NUMBER} REUSSI",
                body: """<h2>Deploiement reussi !</h2>
                    <table>
                        <tr><td><b>Application</b></td><td>${APP_NAME}</td></tr>
                        <tr><td><b>Version</b></td><td>${APP_VERSION}</td></tr>
                        <tr><td><b>Branch</b></td><td>${GIT_BRANCH}</td></tr>
                        <tr><td><b>Monitoring</b></td><td>http://${K8S_HOST}:32000 (Grafana)</td></tr>
                    </table>
                    <p><a href="${BUILD_URL}">Voir le build Jenkins</a></p>""",
                mimeType: 'text/html',
                to: 'lahinirikomarasylvain30@gmail.com'
            )
        }

        failure {
            script {
                sh """
                    echo "" >> ${LOG_FILE}
                    echo "=============================================================" >> ${LOG_FILE}
                    echo "  ECHEC PIPELINE"                                              >> ${LOG_FILE}
                    echo "  Build   : #${BUILD_NUMBER}"                                  >> ${LOG_FILE}
                    echo "  Date    : \$(date '+%Y-%m-%d %H:%M:%S')"                     >> ${LOG_FILE}
                    echo "=============================================================" >> ${LOG_FILE}
                    mkdir -p ${WORKSPACE}/reports
                    cp ${LOG_FILE} ${WORKSPACE}/reports/pipeline-${BUILD_NUMBER}-FAILED.log || true
                """
                archiveArtifacts artifacts: 'reports/pipeline-*-FAILED.log', allowEmptyArchive: true
            }
            script {
                def deployStages = ['Deploy — App + Database', 'Verify Deployment', 'Smoke Tests']
                if (env.STAGE_NAME in deployStages) {
                    sh """
                        echo "[\$(date +%H:%M:%S)] [ROLLBACK] Rollback automatique..." >> ${LOG_FILE}
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
                subject: "[Jenkins] ${APP_NAME} — Build #${BUILD_NUMBER} ECHOUE",
                body: """<h2>Pipeline echoue !</h2>
                    <p><b>Branch :</b> ${GIT_BRANCH}</p>
                    <p><a href="${BUILD_URL}console">Voir les logs</a></p>""",
                mimeType: 'text/html',
                to: 'lahinirikomarasylvain30@gmail.com'
            )
        }

        always {
            cleanWs(patterns: [[pattern: 'target/**', type: 'INCLUDE']])
            sh 'docker image prune -f --filter "until=48h" || true'
        }
    }
}
