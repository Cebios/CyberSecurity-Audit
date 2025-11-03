# 🔐 Security Suite - Réutilisable

Suite complète d'analyse de sécurité automatisée, configurable pour plusieurs projets.

## 🚀 Quick Start

```bash
# 1. Configuration
cp .env.example .env
nano .env  # Définir PROJECT_DIR, DOCKERFILE_PATH, TARGET_URL, DOCKER_IMAGE

# 2. Lancer le menu interactif
./security-scan.sh

# 3. Résultats
./view-results.sh
```

## 📖 Documentation Complète

**→ Voir [GUIDE.md](GUIDE.md) pour :**
- 🛠️ Liste des 15 outils et leur rôle
- ⚙️ Configuration complète (variables d'environnement)
- 🔄 Réutilisation sur d'autres projets
- 🌐 Tests DAST sans blocage OVH (whitelist IP, rate-limiting)
- 📊 Interprétation des résultats
- 🚨 Actions d'urgence et résolution de problèmes

## 🛠️ Outils Inclus (17)

**SAST** : Semgrep, PHPStan, PHP-CS-Fixer  
**SCA** : OWASP Dependency Check, Snyk, Security Checker  
**Conteneurs** : Trivy, Grype, Hadolint  
**Secrets** : GitLeaks, TruffleHog  
**DAST** : OWASP ZAP, Nuclei (configs OVH-friendly)  
**TLS/Headers** : TestSSL, SecurityHeaders  
**Réseau** : Nmap  
**API** : Newman (Postman)

## ⚙️ Variables Clés (.env)

```properties
PROJECT_DIR=./elearning                          # Chemin vers projet
DOCKERFILE_PATH=docker/php                       # Chemin Dockerfile (relatif au projet)
TARGET_URL=https://dev.cebios-lms.fr             # URL à scanner
DOCKER_IMAGE=docker.cebios-lms.fr/app-lms:latest # Image Docker
SNYK_TOKEN=...                                    # Token Snyk (optionnel)
OSSINDEX_USER=...                                 # OSS Index (requis)
OSSINDEX_TOKEN=...                                # OSS Index (requis)
```

## 🔄 Réutilisation

Ce dossier est **indépendant du projet** et peut être réutilisé :

```bash
# Copier pour un nouveau projet
cp -r elearning_secu mon-projet_secu

# Configurer
cd mon-projet_secu
cp .env.example .env
nano .env  # Adapter PROJECT_DIR, TARGET_URL, DOCKER_IMAGE

# Lancer
./security-scan.sh quick
```

Voir section **"Réutilisation sur Autres Projets"** dans [GUIDE.md](GUIDE.md).

---

**Documentation complète** : [GUIDE.md](GUIDE.md)
