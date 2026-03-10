# 🚀 Projet CI/CD Complet — Java App + PostgreSQL + DevSecOps

## 🗺️ Architecture réelle

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PC HÔTE (Ansible + Docker)                                             │
│                                                                         │
│  ┌──────────────────┐    ┌──────────────────┐                          │
│  │  Jenkins         │    │  SonarQube       │                          │
│  │  localhost:8080  │    │  localhost:9000  │                          │
│  │  (Docker)        │    │  (Docker)        │                          │
│  └────────┬─────────┘    └──────────────────┘                          │
│           │ Ansible SSH                                                 │
└───────────┼─────────────────────────────────────────────────────────────┘
            │
     ┌──────┴──────────────────────────────────┐
     │                                         │
     ▼                                         ▼
┌────────────────────────┐    ┌─────────────────────────────────────────┐
│  VM HARBOR             │    │  VM KUBERNETES (Kubeadm)                │
│  192.168.43.133        │    │  192.168.43.109                         │
│  User: lms             │    │  User: lms                              │
│                        │    │                                         │
│  harbor.local (HTTPS)  │    │  Namespace: production                  │
│  ├─ myproject/java-app │    │  ├─ java-app (x2 pods)                  │
│  └─ Trivy scan auto    │◄───│  ├─ postgres                           │
│                        │    │                                         │
└────────────────────────┘    │  Namespace: monitoring                  │
                              │  ├─ Prometheus :30090                   │
                              │  └─ Grafana    :32000                   │
                              └─────────────────────────────────────────┘
```

## 📋 Pipeline CI/CD — 14 Stages

```
Stage 0  │ 📝 Init Logs           → Initialisation fichier log pipeline
Stage 1  │ 📥 Checkout            → Récupération du code Git
Stage 2  │ 🔐 Gitleaks            → [SÉCURITÉ] Détection secrets/credentials
Stage 3  │ 🔍 SonarQube           → [SÉCURITÉ] Analyse vulnérabilités code source
Stage 4  │ 🚦 Quality Gate        → Vérification seuil qualité SonarQube
Stage 5  │ 🏗️  Maven Build         → Compilation + tests unitaires + JaCoCo
Stage 6  │ 🛡️  OWASP               → [SÉCURITÉ] Scan dépendances Maven (CVE)
Stage 7  │ 🐳 Docker Build        → Construction image multi-stage (non-root)
Stage 8  │ 🔬 Trivy               → [SÉCURITÉ] Scan image Docker (bloque HIGH/CRITICAL)
Stage 9  │ 📤 Push Harbor         → Publication sur harbor.local (192.168.43.133)
Stage 10 │ ⚙️  Ansible K8s Setup   → Namespace + Secrets + Certs Harbor
Stage 11 │ 🚀 Deploy              → Rolling update App Java + PostgreSQL
Stage 12 │ ✅ Verify              → Vérification rollout Kubernetes
Stage 13 │ 🧪 Smoke Tests         → Tests health/readiness/metrics
Stage 14 │ 📊 Monitoring          → Prometheus + Grafana (auto-déployés)
```

## 📁 Structure du projet

```
cicd-project/
├── Jenkinsfile                              ← Pipeline principal (14 stages)
├── docker-compose.yml                       ← Jenkins + SonarQube (PC hôte)
├── docker/
│   └── Dockerfile                           ← Image Java multi-stage sécurisée
├── ansible/
│   ├── ansible.cfg                          ← Config Ansible (SSH, logs)
│   ├── inventory/
│   │   └── hosts.yml                        ← IPs réelles (133 + 109)
│   └── playbooks/
│       ├── setup-kubernetes.yml             ← Namespace + Secrets + Certs
│       ├── deploy-app.yml                   ← Deploy App + PostgreSQL
│       ├── verify-deployment.yml            ← Vérification + Rollback
│       └── setup-monitoring.yml             ← Prometheus + Grafana
├── kubernetes/
│   ├── app/
│   │   ├── deployment.yml                   ← App Java (HA, sécurisé)
│   │   └── service.yml                      ← Service NodePort :30080 + HPA
│   ├── database/
│   │   └── postgres-deployment.yml          ← PostgreSQL + PVC + Service
│   └── monitoring/
│       ├── prometheus/
│       │   ├── rbac.yml                     ← ServiceAccount + ClusterRole
│       │   ├── configmap.yml                ← Config + règles d'alertes
│       │   └── deployment.yml               ← Prometheus NodePort :30090
│       └── grafana/
│           └── deployment.yml               ← Grafana + dashboard auto :32000
└── scripts/
    ├── setup-ssh.sh                         ← Config clés SSH Ansible
    └── smoke-tests.sh                       ← Tests post-déploiement
```

---

## ⚡ Démarrage en 6 étapes

### Étape 1 — Configurer les clés SSH Ansible
```bash
bash scripts/setup-ssh.sh
# Configure et teste SSH vers les deux VMs (lms@192.168.43.133 et lms@192.168.43.109)
```

### Étape 2 — Récupérer le certificat CA Harbor
```bash
# Se connecter à la VM Harbor et récupérer le CA
scp lms@192.168.43.133:/opt/infra-setup/harbor/certs/ca.crt ./harbor-ca.crt
```

### Étape 3 — Démarrer SonarQube
```bash
# Paramètre système obligatoire pour SonarQube
sudo sysctl -w vm.max_map_count=262144

# Démarrer les services
docker compose up -d

# Attendre (~2 min) puis vérifier
docker compose ps
```

### Étape 4 — Configurer les credentials Jenkins
```
Jenkins > Manage Jenkins > Credentials > System > Global > Add

① harbor-credentials    → Username/Password
   Username: robot$jenkins-robot
   Password: <secret Harbor robot>

② sonarqube-token       → Secret text
   Secret: <token SonarQube>

③ kubeconfig            → Secret file
   File: ~/.kube/config de la VM 192.168.43.109
```

### Étape 5 — Récupérer le kubeconfig de la VM K8s
```bash
# Sur la VM Kubernetes (192.168.43.109)
ssh lms@192.168.43.109 "cat ~/.kube/config" > /tmp/k8s-config
# Puis l'ajouter dans Jenkins > Credentials > kubeconfig
```

### Étape 6 — Créer et lancer le pipeline Jenkins
```
Jenkins > New Item > java-app-pipeline
Type : Multibranch Pipeline
Source : URL de votre dépôt Git
Credentials : git-credentials
Jenkinsfile : Jenkinsfile
```

---

## 📊 Accès aux interfaces

| Service | URL | Credentials |
|---------|-----|-------------|
| Jenkins | http://localhost:8080 | admin / admin |
| SonarQube | http://localhost:9000 | admin / admin |
| Harbor | https://harbor.local | admin / Harbor@12345 |
| Application | http://192.168.43.109:30080 | — |
| Prometheus | http://192.168.43.109:30090 | — |
| Grafana | http://192.168.43.109:32000 | admin / admin |

---

## 📝 Logs du pipeline

Les logs de chaque build sont automatiquement sauvegardés :

```bash
# Dans le conteneur Jenkins
/var/jenkins_home/pipeline-logs/java-app-build-<N>.log

# Télécharger via Jenkins
Jenkins > java-app-pipeline > Build #N > Artifacts > pipeline-<N>.log

# Depuis le PC hôte (volume Docker)
docker exec jenkins ls /var/jenkins_home/pipeline-logs/
docker cp jenkins:/var/jenkins_home/pipeline-logs/java-app-build-1.log ./
```

Format du log :
```
=============================================================
  JENKINS PIPELINE LOG
  Application : java-app
  Build N°    : 42
  Branch      : main
  Commit      : abc1234
  Date        : 2024-01-15 10:30:00
=============================================================
[10:30:01] [INIT]     Pipeline démarré
[10:30:02] [CHECKOUT] Branch: main | Auteur: John Doe
[10:30:15] [GITLEAKS] ✅ Aucun secret détecté
[10:31:00] [SONAR]    ✅ Analyse SonarQube terminée
[10:31:05] [QUALITY-GATE] Statut: OK
[10:33:20] [BUILD]    ✅ Build Maven réussi
[10:35:00] [OWASP]    ✅ Scan OWASP terminé
[10:36:00] [DOCKER]   ✅ Image construite
[10:37:30] [TRIVY]    ✅ Aucune vulnérabilité CRITICAL/HIGH
[10:38:00] [HARBOR]   ✅ Image poussée
[10:39:00] [ANSIBLE]  ✅ Infrastructure Kubernetes prête
[10:41:00] [DEPLOY]   ✅ Déploiement Kubernetes terminé
[10:42:00] [VERIFY]   ✅ Déploiement vérifié
[10:42:30] [SMOKE]    ✅ Smoke tests réussis
[10:43:00] [MONITORING] ✅ Prometheus + Grafana opérationnels
=============================================================
  ✅ PIPELINE RÉUSSI  | Build #42 | Durée: 13 min
=============================================================
```

---

## 🔐 Sécurité — Contrôle à chaque étape

| Stage | Outil | Ce qui est vérifié | Action si KO |
|-------|-------|-------------------|--------------|
| 2 | **Gitleaks** | Secrets, tokens, passwords dans le code | ❌ Arrêt immédiat |
| 3 | **SonarQube** | OWASP Top 10, injections, vulnérabilités code | ❌ Arrêt si Quality Gate KO |
| 6 | **OWASP DC** | CVE dans les dépendances Maven (CVSS ≥ 7) | ⚠️ Warning (configurable) |
| 8 | **Trivy** | CVE dans l'image Docker (HIGH/CRITICAL) | ❌ Arrêt immédiat |
| 11 | **K8s Security** | runAsNonRoot, readOnlyFS, drop ALL caps | — Appliqué automatiquement |

---

## 🔄 Rollback automatique

En cas d'échec lors du déploiement, verify ou smoke tests, le pipeline déclenche automatiquement :
```bash
kubectl rollout undo deployment/java-app -n production
```

Rollback manuel :
```bash
ssh lms@192.168.43.109
kubectl rollout undo deployment/java-app -n production
kubectl rollout history deployment/java-app -n production
```
