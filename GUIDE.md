# 🔐 Guide Complet de Sécurité

Suite complète de tests de sécurité automatisés, réutilisable sur plusieurs projets.

---

## � Table des Matières

1. [�🚀 Démarrage Rapide](#-démarrage-rapide)
2. [📋 Commandes Principales](#-commandes-principales)
3. [🛠️ Outils & Leur Rôle](#️-outils--leur-rôle)
4. [⚙️ Configuration](#️-configuration)
5. [🔄 Réutilisation sur Autres Projets](#-réutilisation-sur-autres-projets)
6. [🌐 Tests DAST sans Blocage OVH](#-tests-dast-sans-blocage-ovh)
7. [📊 Interprétation des Résultats](#-interprétation-des-résultats)
8. [🔄 Workflows par Rôle](#-workflows-par-rôle)
9. [🚨 Actions d'Urgence](#-actions-durgence)
10. [🐛 Résolution de Problèmes](#-résolution-de-problèmes)

---

## 🚀 Démarrage Rapide

```bash
# 1. Vérifier Docker
docker --version

# 2. Configurer les variables
cp .env.example .env
nano .env  # Remplir PROJECT_DIR, DOCKERFILE_PATH, TARGET_URL, DOCKER_IMAGE

# 3. Se connecter au registry (si nécessaire)
docker login docker.cebios-lms.fr

# 4. Lancer le menu interactif
./security-scan.sh

# 5. Voir les résultats
./view-results.sh
```

---

## 📋 Commandes Principales

### Menu Interactif

```bash
./security-scan.sh
```

Le script affiche un **menu interactif** avec les options suivantes :

| Option | Description | Durée |
|--------|-------------|-------|
| **1** | Scan Rapide (Quick) | ~15-30 min |
| **2** | Scan Complet (Full) | ~2-4h |
| **3** | Analyse du Code Source | ~5-10 min |
| **4** | Analyse des Dépendances | ~10-15 min |
| **5** | Tests Dynamiques Web | ~30 min - 1h |
| **6** | Scan Conteneurs Docker | ~5-10 min |
| **7** | Détection Secrets | ~2-5 min |
| **8** | Vérifier Configuration | <1 min |
| **9** | Nettoyer les rapports | <1 min |
| **0** | Quitter | - |

### Consulter les Résultats

```bash
./view-results.sh   # Résumé visuel de tous les rapports
```

### Outils Individuels

#### 🔧 Exécution Manuelle avec Génération de Rapports

**Important :** Pour générer automatiquement les rapports dans `reports/`, utilisez ces commandes avec redirection :

```bash
# 🧠 SAST - Analyse du Code Source
docker compose run --rm semgrep > reports/semgrep/semgrep-report.json 2>&1
docker compose run --rm phpstan > reports/phpstan/phpstan-report.json 2>&1
docker compose run --rm php_cs_fixer > reports/php-cs-fixer/php-cs-fixer-report.json 2>&1

# 📦 SCA - Analyse des Dépendances
docker compose run --rm dependency_check > reports/dependency-check/dependency-check-report.html 2>&1
docker compose run --rm snyk > reports/snyk/snyk-report.json 2>&1
docker compose run --rm local_php_security > reports/security-checker/security-checker-report.json 2>&1

# 🐳 Sécurité des Conteneurs
docker compose run --rm trivy > reports/trivy/trivy-report.txt 2>&1
docker compose run --rm grype > reports/grype/grype-report.txt 2>&1
docker compose run --rm hadolint > reports/hadolint/hadolint-report.txt 2>&1

# 🔑 Détection de Secrets
docker compose run --rm gitleaks > reports/gitleaks/gitleaks-report.json 2>&1
docker compose run --rm trufflehog > reports/trufflehog/trufflehog-report.json 2>&1

# 🌐 DAST - Tests Dynamiques Web
docker compose run --rm zap_baseline > reports/zap/zap-baseline-report.html 2>&1
docker compose run --rm zap_full > reports/zap/zap-full-report.html 2>&1

# 🔐 TLS/SSL & En-têtes
docker compose run --rm testssl > reports/testssl/testssl-report.html 2>&1
docker compose run --rm securityheaders > reports/securityheaders/securityheaders-report.json 2>&1

# 🌍 Scan Réseau
docker compose run --rm nmap > reports/nmap/nmap-report.txt 2>&1
docker compose run --rm nuclei > reports/nuclei/nuclei-report.txt 2>&1

# 🧾 Tests API
docker compose run --rm newman > reports/newman/newman-report.json 2>&1
```

**Note :** Le script `security-scan.sh` exécute automatiquement toutes ces commandes avec les bonnes redirections. Les commandes ci-dessus sont pour l'exécution manuelle individuelle.

---

## 🛠️ Outils & Leur Rôle

### 🧠 SAST - Analyse du Code Source

**Semgrep**
- Détecte : Injections SQL, XSS, CSRF, failles OWASP Top 10
- Rapport : `reports/semgrep/semgrep-report.json`

**PHPStan**
- Détecte : Erreurs de typage, bugs logiques, code mort, mauvaises pratiques PHP
- Niveau : Analyse stricte avec configuration sécurité
- Rapport : `reports/phpstan/phpstan-report.json`
- Lancez via : `docker compose run --rm phpstan`

**PHP-CS-Fixer**
- Détecte : Non-conformité aux standards PSR, problèmes de style et qualité de code
- Rapport : `reports/php-cs-fixer/php-cs-fixer-report.json`
- Lancez via : `docker compose run --rm php_cs_fixer`

### 📦 SCA - Analyse des Dépendances

**OWASP Dependency Check**
- Détecte : Vulnérabilités connues dans composer.lock et toutes les dépendances du projet
- Base : National Vulnerability Database (NVD) - base de données officielle des failles de sécurité + OSS Index (Sonatype)
- Rapport : `reports/dependency-check/dependency-check-report.html`
- ⚙️ Config faux positifs : `elearning/dependency-check-suppressions.xml`
- 🔐 OSS Index : Nécessite `OSS_INDEX_USERNAME` et `OSS_INDEX_API_KEY` (authentification obligatoire)
- 🚀 Performance : Ajoutez `NVD_API_KEY` dans `.env` pour accélérer les scans (sans clé : plusieurs minutes, avec clé : quelques secondes)

**Snyk** (optionnel, nécessite token)
- Détecte : Vulnérabilités avec base plus récente
- Obtenir token : https://snyk.io
- Config : `SNYK_TOKEN` dans `.env`

**NVD API Key** (fortement recommandé pour Dependency Check)
- Accélère considérablement les mises à jour de la base de vulnérabilités
- Obtenir clé : https://nvd.nist.gov/developers/request-an-api-key
- Config : `NVD_API_KEY` dans `.env`

**Local PHP Security Checker**
- Détecte : Vulnérabilités connues dans composer.lock
- Rapport : `reports/security-checker/security-checker.json`

### 🐳 Sécurité des Conteneurs

**Trivy**
- Détecte : Failles de sécurité connues dans les images Docker
- Rapport : `reports/trivy/trivy-report.json`

**Grype**
- Détecte : Vulnérabilités dans les conteneurs (alternatif à Trivy)
- Rapport : `reports/grype/grype-report.json`

**Hadolint**
- Détecte : Mauvaises pratiques dans Dockerfile
- Rapport : `reports/hadolint/hadolint-report.json`

### 🔑 Détection de Secrets

**GitLeaks** ⚠️ CRITIQUE
- Détecte : Mots de passe, clés API, tokens hardcodés
- Rapport : `reports/gitleaks/gitleaks-report.json`
- Action : Rotation immédiate si secrets trouvés !

**TruffleHog**
- Détecte : Secrets (complément GitLeaks)
- Rapport : `reports/trufflehog/trufflehog-report.json`

### 🌐 DAST - Tests Dynamiques Web

**OWASP ZAP Baseline**
- Détecte : Vulnérabilités web par scan passif
- Rapport : `reports/zap/zap-baseline-report.html`
- ⚙️ Config : `.zap/rules.tsv`
- ⚠️ **Whitelister votre IP OVH** : `./whitelist-ip.sh` (voir `DAST_OVH.md`)

**OWASP ZAP Full** (mode `full` uniquement)
- Détecte : Scan actif complet (⚠️ attaque réelle)
- Durée : 1-3h
- ⚠️ **Whitelist IP obligatoire** + uniquement sur vos serveurs de test !

**Nuclei**
- Détecte : Failles de sécurité connues, services exposés, erreurs de configuration
- Templates : Mis à jour automatiquement
- Rapport : `reports/nuclei/nuclei-report.json`
- ⚠️ Rate-limited pour éviter blocage OVH

### 🔐 TLS/SSL & En-têtes

**TestSSL**
- Vérifie : Protocoles SSL/TLS, chiffrement, certificats
- Détecte : Failles connues comme POODLE, Heartbleed, etc.
- Rapport : `reports/testssl/testssl-report.html`

**SecurityHeaders**
- Vérifie : En-têtes de sécurité HTTP (CSP, X-Frame-Options, HSTS, etc.)
- Rapport : `reports/securityheaders/`

### 🌍 Scan Réseau

**Nmap** (mode `full` uniquement)
- Détecte : Ports ouverts, services exposés
- ⚠️ Uniquement sur vos propres serveurs !

### 🧾 Tests API

**Newman (Postman)**
- Tests : Authentification, autorisation, injection, headers
- Config : `tests/api_collection.json`
- Rapport : `reports/newman/newman-report.html`

---

## ⚙️ Configuration

### 1. Variables d'environnement (`.env`)

```bash
# Copier le template
cp .env.example .env

# Éditer
nano .env
```

### 2. Registry Docker privé

```bash
# Se connecter une fois
docker login docker.cebios-lms.fr

# Les scans utiliseront automatiquement vos credentials
```

---

## 🔄 Réutilisation sur Autres Projets

Ce dossier de sécurité est conçu pour être **réutilisable sur plusieurs projets**. Voici comment l'adapter.

### Étapes de Configuration

#### 1. Copier le dossier de sécurité

```bash
# Ou cloner depuis Git si vous l'avez versionnée
git clone <repo-security-tools> mon-nouveau-projet_secu
```

#### 2. Configurer les variables d'environnement

```bash
cd mon-nouveau-projet_secu

# Copier le template
cp .env.example .env

# Éditer le fichier .env
nano .env
```

**Modifier ces 3 variables critiques :**

```properties
# Chemin relatif vers votre projet (depuis ce dossier)
PROJECT_DIR=./mon-projet

# Chemin vers le Dockerfile (relatif au projet)
DOCKERFILE_PATH=docker/php

# URL de votre application
TARGET_URL=https://mon-app.example.com

# Image Docker à scanner
DOCKER_IMAGE=registry.example.com/mon-app:latest
```

#### 3. Organiser l'arborescence

**Option A - Projet à côté du dossier de sécurité (recommandé)**

```
mon-workspace/
├── mon-projet/              # Votre projet PHP
│   ├── src/
│   ├── composer.json
│   └── ...
└── mon-projet_secu/         # Ce dossier de sécurité
    ├── docker-compose.yml
    ├── security-scan.sh
    ├── .env                 # PROJECT_DIR=../mon-projet
    └── reports/
```

Configuration `.env` :
```properties
PROJECT_DIR=../mon-projet
```

**Option B - Projet dans un sous-dossier**

```
mon-projet_secu/
├── mon-projet/              # Votre projet
│   ├── src/
│   └── composer.json
├── docker-compose.yml
├── security-scan.sh
├── .env                     # PROJECT_DIR=./mon-projet
└── reports/
```

Configuration `.env` :
```properties
PROJECT_DIR=./mon-projet
```

### Exemples de Configuration

#### Exemple 1 : Application Laravel sur AWS

```properties
PROJECT_DIR=../laravel-app
DOCKERFILE_PATH=docker/app
TARGET_URL=https://staging.myapp.aws.com
DOCKER_IMAGE=123456789.dkr.ecr.eu-west-1.amazonaws.com/laravel-app:staging
SNYK_TOKEN=abc123...
OSS_INDEX_USERNAME=dev@mycompany.com
OSS_INDEX_API_KEY=xyz789...
NVD_API_KEY=nvd_abc123...
```

#### Exemple 2 : API Symfony sur OVH

```properties
PROJECT_DIR=./symfony-api
DOCKERFILE_PATH=docker/php-fpm
TARGET_URL=https://api.example.ovh
DOCKER_IMAGE=docker.example.fr/api:latest
SNYK_TOKEN=def456...
OSS_INDEX_USERNAME=security@example.com
OSS_INDEX_API_KEY=tuv012...
NVD_API_KEY=nvd_def456...
```

#### Exemple 3 : Projet WordPress local

```properties
PROJECT_DIR=../wordpress
DOCKERFILE_PATH=Dockerfile
TARGET_URL=http://localhost:8080
DOCKER_IMAGE=wordpress:latest
```

### Adapter pour d'autres langages

**Pour un projet Node.js :**

Modifier `docker-compose.yml` :

```yaml
snyk:
  image: snyk/snyk:node      # Changer l'image
  # ...
```

**Pour Python :**

```yaml
snyk:
  image: snyk/snyk:python
  # ...
```

### Checklist de Configuration

- [ ] Copier `.env.example` vers `.env`
- [ ] Définir `PROJECT_DIR` (chemin vers le projet)
- [ ] Définir `DOCKERFILE_PATH` (chemin relatif vers Dockerfile)
- [ ] Définir `TARGET_URL` (URL de l'application)
- [ ] Définir `DOCKER_IMAGE` (image à scanner)
- [ ] Configurer `SNYK_TOKEN` (optionnel)
- [ ] Configurer `OSS_INDEX_USERNAME` et `OSS_INDEX_API_KEY` (recommandé)
- [ ] Configurer `NVD_API_KEY` (fortement recommandé pour accélérer Dependency Check)
- [ ] Tester avec `./security-scan.sh quick`
- [ ] Vérifier les rapports dans `./reports/`
- [ ] Pour DAST : whitelister votre IP chez l'hébergeur

---

## 🌐 Tests DAST sans Blocage OVH

### ⚠️ Le Problème

Les outils DAST (ZAP, Nuclei) envoient beaucoup de requêtes rapidement, ce qui peut déclencher :
- 🛡️ **WAF OVH** : Blocage des patterns d'attaque
- 🚫 **Anti-DDoS** : Rate limiting / bannissement IP
- 🔒 **Fail2ban** : Blocage après tentatives suspectes

### ✅ Solutions

#### Solution 1 : Whitelister votre IP (Recommandé)

**Dans Fail2ban (si serveur dédié/VPS) :**

```bash
# SSH sur le serveur
ssh user@dev.cebios-lms.fr

# Whitelister votre IP
sudo fail2ban-client set nginx-limit-req addignoreip VOTRE_IP
sudo fail2ban-client status
```

**Dans nginx directement :**

```nginx
# /etc/nginx/sites-available/votresite
location / {
    # Autoriser votre IP
    allow VOTRE_IP;
    
    # Le reste des règles
    ...
}
```

#### Solution 2 : Utiliser un environnement de test dédié

Créer un sous-domaine sans protections :

```bash
# Sous-domaine : test.cebios-lms.fr
# Sans WAF, sans rate limiting, IP whitelistée
```

Dans `.env` :
```properties
TARGET_URL=https://test.cebios-lms.fr
```

#### Solution 3 : Scanner depuis le serveur lui-même

```bash
# SSH sur le serveur
ssh user@dev.cebios-lms.fr

# Cloner le projet et scanner en local
TARGET_URL=http://localhost ./security-scan.sh quick
```

### 📊 Stratégie Progressive

**Étape 1 : Tests légers (sans risque de blocage)**

```bash
docker compose run --rm semgrep
docker compose run --rm dependency_check
docker compose run --rm gitleaks
```

**Étape 2 : Tests passifs (peu de risque)**

```bash
docker compose run --rm testssl
docker compose run --rm securityheaders
```

**Étape 3 : Tests actifs APRÈS whitelist**

```bash
docker compose run --rm zap_baseline
docker compose run --rm nuclei
```

### 🚨 Si vous êtes bloqué

```bash
# Débloquer depuis le serveur
ssh user@dev.cebios-lms.fr
sudo fail2ban-client unban VOTRE_IP

# Vérifier les logs
sudo tail -f /var/log/nginx/access.log | grep "VOTRE_IP"
sudo fail2ban-client status nginx-limit-req
```

## 📊 Interprétation des Résultats

### Niveaux de criticité

| Niveau | Délai | Action |
|--------|-------|--------|
| 🔴 **CRITIQUE** | < 24h | Correction immédiate + rotation des identifiants |
| 🟠 **ÉLEVÉ** | < 1 semaine | Correction prioritaire |
| 🟡 **MOYEN** | < 1 mois | Planifier correction |
| 🟢 **FAIBLE** | Backlog | À traiter si temps disponible |

### Ordre de priorité

1. **🔑 Secrets détectés** → Rotation immédiate des identifiants
2. **💉 Injections SQL/XSS** → Correction critique
3. **📦 Vulnérabilités critiques dans les dépendances** → Mise à jour des bibliothèques
4. **🔐 SSL/TLS** → Améliorer configuration du chiffrement
5. **📋 En-têtes HTTP** → Ajouter les en-têtes de sécurité manquants

### 🔍 Scanners de Conteneurs : Trivy vs Grype

**Pour les conteneurs Alpine Linux** (comme votre image PHP), **faites confiance à Trivy** qui est spécialisé dans les distributions Linux spécifiques :

- **✅ Trivy** : Utilise directement la base de données de sécurité Alpine → **résultats précis**
- **⚠️ Grype** : Utilise la NVD générale → **beaucoup de faux positifs** pour Alpine

**Exemple concret :**
- Grype détecte ~15 vulnérabilités dans ImageMagick, Calendar, Perl...
- Trivy n'en détecte **aucune** pour Alpine 3.22

**Recommandation :** Utilisez Trivy comme référence pour Alpine. Grype peut détecter des vulnérabilités supplémentaires mais nécessite un filtrage manuel des faux positifs.

### Consulter les rapports

```bash
# Résumé visuel
./view-results.sh

# Rapports HTML
open reports/zap/zap-baseline-report.html
open reports/dependency-check/dependency-check-report.html
open reports/testssl/testssl-report.html

# Rapport consolidé
cat reports/security-report-*.md

# Vérifier secrets
cat reports/gitleaks/gitleaks-report.json
```

---

## 🔄 Workflows de Sécurité

### 💻 A chaque commit (déjà intégré au workflow github actions)

```bash
# 1. Vérifier qu'il n'y a pas de secrets dans votre code
docker compose run --rm gitleaks

# 2 Détecte les erreurs de code
docker compose run --rm phpstan        
# 3 Verifie les standards du code       
docker compose run --rm php_cs_fixer          

# Temps total : ~2-5 minutes
```

**Quand ?** Avant chaque `git commit` ou `git push`  
**Pourquoi ?** Éviter de committer des mots de passe ou du code de mauvaise qualité

---

### � Scan rapide hebdomadaire (quick)

Pour un **contrôle régulier** de la sécurité du projet :

```bash
./security-scan.sh quick
./view-results.sh
```

**Ce qui est scanné :**
- ✅ Code source (injections SQL, XSS, failles OWASP)
- ✅ Dépendances (vulnérabilités dans les bibliothèques)
- ✅ Secrets exposés
- ✅ Images Docker
- ✅ Qualité du code PHP

**Quand ?** Une fois par semaine, ou après avoir ajouté de nouvelles dépendances  
**Durée :** ~15-30 minutes  
**Pourquoi ?** Détecter rapidement les nouvelles vulnérabilités dans les bibliothèques ou les erreurs de code

---

### � Scan complet avant release (full)

Pour une **validation complète** avant mise en production :

```bash
./security-scan.sh full
./view-results.sh
cat reports/security-report-*.md
```

**Ce qui est scanné en plus :**
- ✅ Tout ce que fait le scan `quick`
- ✅ Tests dynamiques web (OWASP ZAP Full - scan actif)
- ✅ Scan réseau (Nmap - ports ouverts)
- ✅ Tests API approfondis

**Quand ?**
- Avant de fusionner une grosse fonctionnalité
- Avant une release majeure
- Au moins une fois par mois

**Durée :** ~2-4 heures  
**Pourquoi ?** S'assurer qu'aucune faille critique n'existe avant de déployer en production

---

### 📋 Récapitulatif : Quand faire quoi ?

| Situation | Action | Outils | Temps |
|-----------|--------|--------|-------|
| Avant chaque commit | Vérifications rapides | GitLeaks + PHPStan + PHP-CS-Fixer | 2-5 min |
| Ajout de dépendances | Scan quick | Tous les outils SAST/SCA | 15-30 min |
| Une fois par semaine | Scan quick | Tous les outils SAST/SCA | 15-30 min |
| Avant mise en production | Scan full | Tous les outils + DAST + Nmap | 2-4h |
| Grosse fonctionnalité | Scan full | Tous les outils + DAST + Nmap | 2-4h |

---

### 💡 Exemple de workflow pour un développeur

**Lundi matin (début de sprint) :**
```bash
./security-scan.sh
# Choisir l'option 1 (Scan Rapide)
# Traiter les vulnérabilités détectées avant de commencer
```

**Pendant la semaine (développement) :**
```bash
# Avant chaque commit - via menu ou directement
./security-scan.sh  # Option 7 (Secrets) puis Option 3 (Analyse Code Source)

# Ou directement :
docker compose run --rm gitleaks
docker compose run --rm phpstan
docker compose run --rm php_cs_fixer
```

**Vendredi (avant merge/release) :**
```bash
./security-scan.sh
# Choisir l'option 2 (Scan Complet)
./view-results.sh
# Corriger les problèmes critiques avant de merger
```



---

## 🚨 Actions d'Urgence

### Si secrets détectés

```bash
# 1. Identifier
cat reports/gitleaks/gitleaks-report.json

# 2. Supprimer du code
git log -S "secret_value" --all  # Trouver dans l'historique

# 3. Rotation immédiate des credentials
# 4. Vérifier logs serveur pour usage malveillant
```

### Si vulnérabilités critiques détectées

```bash
# 1. Voir détails
open reports/dependency-check/dependency-check-report.html

# 2. Mettre à jour les bibliothèques
cd elearning && composer update

# 3. Re-scanner
docker compose run --rm dependency_check
```

### Si faux positifs

```bash
# Dependency Check
nano elearning/dependency-check-suppressions.xml

# GitLeaks
nano .gitleaksignore

# ZAP
nano .zap/rules.tsv
```

---

## 🐛 Résolution de Problèmes

### Erreur "unauthorized" sur registry Docker

```bash
docker login docker.cebios-lms.fr
docker pull docker.cebios-lms.fr/app-lms:latest
```

### Outil en erreur

```bash
# Voir logs
docker compose logs <nom-outil>

# Nettoyer et relancer
./security-scan.sh clean
docker compose run --rm <nom-outil>
```

### Rapports vides

```bash
# Vérifier permissions
ls -la reports/

# Recréer les dossiers
rm -rf reports/
./security-scan.sh quick
```

---

## 📁 Structure des Rapports

```
reports/
├── semgrep/              # Analyse code source
├── phpstan/              # Analyse statique PHP
├── php-cs-fixer/         # Standards de code PHP
├── dependency-check/     # Vulnérabilités des bibliothèques
├── gitleaks/             # Secrets détectés ⚠️
├── trivy/                # Vulnérabilités dans les conteneurs
├── zap/                  # Scan web dynamique
├── nuclei/               # Failles connues et services exposés
├── testssl/              # Configuration SSL/TLS
└── newman/               # Tests API
```

## 📚 Ressources

- 🌐 [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- 🔍 [Semgrep Rules](https://semgrep.dev/explore)
- 🛡️ [OWASP ZAP Docs](https://www.zaproxy.org/docs/)
- 📦 [Snyk](https://snyk.io)
- 🐳 [Trivy Docs](https://aquasecurity.github.io/trivy/)
- 🔐 [OSS Index](https://ossindex.sonatype.org/)
- 🗄️ [NVD (National Vulnerability Database)](https://nvd.nist.gov/)

---

**Version** : 2.0.0  
**Dernière mise à jour** : 31 octobre 2025  
**Guide unifié** : Configuration + Réutilisation + DAST OVH