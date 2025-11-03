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
nano .env  # Remplir PROJECT_DIR, TARGET_URL, DOCKER_IMAGE

# 3. Se connecter au registry (si nécessaire)
docker login docker.cebios-lms.fr

# 4. Lancer le scan (15-30 min)
./security-scan.sh quick

# 5. Voir les résultats
./view-results.sh
```

---

## 📋 Commandes Principales

| Commande | Description | Durée |
|----------|-------------|-------|
| `./security-scan.sh quick` | Scan rapide complet | ~30 min |
| `./security-scan.sh full` | Scan exhaustif + Nmap + ZAP Full | ~2-4h |
| `./view-results.sh` | Résumé visuel des résultats | <1 min |
| `./security-scan.sh clean` | Nettoyer conteneurs et volumes | <1 min |

### Outils Individuels

```bash
docker compose run --rm gitleaks              # Détection de secrets
docker compose run --rm dependency_check      # Vulnérabilités dépendances
docker compose run --rm semgrep               # Analyse SAST
docker compose run --rm zap_baseline          # Scan web dynamique
docker compose run --rm trivy                 # Vulnérabilités conteneurs

# Outils déjà intégrés au projet
cd elearning && ./app.sh code-quality-check   # PHPStan + PHP-CS-Fixer
cd elearning && ./test-coverage.sh            # PHPUnit + Couverture
```

---

## 🛠️ Outils & Leur Rôle

### 🧠 SAST - Analyse du Code Source

**Semgrep**
- Détecte : Injections SQL, XSS, CSRF, failles OWASP Top 10
- Rapport : `reports/semgrep/semgrep-report.json`

**PHPStan & PHP-CS-Fixer** *(déjà intégrés dans le projet)*
- Lancez via : `cd elearning && ./app.sh code-quality-check`
- PHPStan : Analyse statique PHP niveau 9
- PHP-CS-Fixer : Vérification standards PSR

**PHPUnit** *(déjà intégré dans le projet)*
- Lancez via : `cd elearning && ./test-coverage.sh`
- Tests unitaires avec couverture de code

### 📦 SCA - Analyse des Dépendances

**OWASP Dependency Check**
- Détecte : CVE dans composer.lock et dépendances
- Base : National Vulnerability Database (NVD)
- Rapport : `reports/dependency-check/dependency-check-report.html`
- ⚙️ Config faux positifs : `elearning/dependency-check-suppressions.xml`

**Snyk** (optionnel, nécessite token)
- Détecte : Vulnérabilités avec base plus récente
- Obtenir token : https://snyk.io
- Config : `SNYK_TOKEN` dans `.env`

**Local PHP Security Checker**
- Détecte : Vulnérabilités connues dans composer.lock
- Rapport : `reports/security-checker/security-checker.json`

### 🐳 Sécurité des Conteneurs

**Trivy**
- Détecte : CVE dans les images Docker
- Rapport : `reports/trivy/trivy-report.json`

**Grype**
- Détecte : Vulnérabilités conteneurs (alternatif à Trivy)
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
- Détecte : CVE connues, expositions, misconfigurations
- Templates : Mis à jour automatiquement
- Rapport : `reports/nuclei/nuclei-report.json`
- ⚠️ Rate-limited pour éviter blocage OVH

### 🔐 TLS/SSL & En-têtes

**TestSSL**
- Vérifie : Protocoles SSL/TLS, chiffrement, certificats
- Détecte : POODLE, Heartbleed, etc.
- Rapport : `reports/testssl/testssl-report.html`

**SecurityHeaders**
- Vérifie : CSP, X-Frame-Options, HSTS, etc.
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

**Variables importantes :**
```properties
# Répertoire du projet à scanner (relatif au dossier de sécurité)
PROJECT_DIR=./elearning

# Snyk (optionnel mais recommandé)
SNYK_TOKEN=votre-token

# OSS Index / Sonatype (REQUIS depuis 2024 pour Dependency Check)
OSSINDEX_USER=votre-email@exemple.com
OSSINDEX_TOKEN=votre-token-ossindex

# Cibles de scan
TARGET_URL=https://dev.cebios-lms.fr
DOCKER_IMAGE=docker.cebios-lms.fr/app-lms:latest
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
# Copier tout le dossier (sans le projet elearning)
cp -r /path/to/elearning_secu /path/to/mon-nouveau-projet_secu

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
TARGET_URL=https://staging.myapp.aws.com
DOCKER_IMAGE=123456789.dkr.ecr.eu-west-1.amazonaws.com/laravel-app:staging
SNYK_TOKEN=abc123...
OSSINDEX_USER=dev@mycompany.com
OSSINDEX_TOKEN=xyz789...
```

#### Exemple 2 : API Symfony sur OVH

```properties
PROJECT_DIR=./symfony-api
TARGET_URL=https://api.example.ovh
DOCKER_IMAGE=docker.example.fr/api:latest
SNYK_TOKEN=def456...
OSSINDEX_USER=security@example.com
OSSINDEX_TOKEN=tuv012...
```

#### Exemple 3 : Projet WordPress local

```properties
PROJECT_DIR=../wordpress
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
- [ ] Définir `TARGET_URL` (URL de l'application)
- [ ] Définir `DOCKER_IMAGE` (image à scanner)
- [ ] Configurer `SNYK_TOKEN` (optionnel)
- [ ] Configurer `OSSINDEX_USER` et `OSSINDEX_TOKEN` (recommandé)
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

```bash
# Récupérer votre IP publique
./whitelist-ip.sh

# Ou manuellement
curl -s ifconfig.me
```

**Dans le WAF OVH :**
1. Espace client OVH → Web Cloud → Hébergement
2. Sélectionner votre domaine
3. Sécurité → Firewall applicatif
4. Ajouter votre IP en liste blanche

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

#### Solution 3 : Ralentir les scans

Les configurations dans `docker-compose.yml` sont déjà optimisées pour OVH :

```yaml
# ZAP - Mode "poli"
zap_baseline:
  command: >
    -z "-config connection.timeoutInSecs=60"  # Timeout plus long
    -z "-config scanner.threadPerHost=2"      # Seulement 2 threads

# Nuclei - Rate limiting
nuclei:
  command: >
    -rate-limit 5        # Max 5 requêtes/seconde
    -timeout 45          # Timeout 45s
    -retries 1           # 1 seule tentative
```

#### Solution 4 : Scanner depuis le serveur lui-même

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
# Whitelister votre IP d'abord
./whitelist-ip.sh

# Puis lancer ZAP et Nuclei
docker compose run --rm zap_baseline
docker compose run --rm nuclei
```

### 🚨 Si vous êtes bloqué

```bash
# 1. Changer d'IP (VPN, 4G, etc.)
# Ou attendre 30 min - 1h

# 2. Débloquer depuis le serveur
ssh user@dev.cebios-lms.fr
sudo fail2ban-client unban VOTRE_IP

# 3. Vérifier les logs
sudo tail -f /var/log/nginx/access.log | grep "VOTRE_IP"
sudo fail2ban-client status nginx-limit-req
```

### 💡 Bonnes Pratiques DAST

**✅ À FAIRE**
- Whitelister votre IP de bureau
- Utiliser un sous-domaine de test
- Scanner en heures creuses
- Prévenir l'équipe ops avant scan
- Commencer par mode passif
- Utiliser rate-limiting

**❌ À NE PAS FAIRE**
- Scanner la prod sans autorisation
- Lancer ZAP Full sans whitelist
- Scanner sans prévenir
- Utiliser threads/workers élevés
- Ignorer les bannissements

### 📝 Checklist Avant Scan DAST

- [ ] IP whitelistée dans WAF OVH
- [ ] Environnement de test utilisé
- [ ] Rate limiting configuré
- [ ] Équipe prévenue
- [ ] Scan en heures creuses
- [ ] Mode passif testé avant
- [ ] Logs accessibles pour debug

---

## 📊 Interprétation des Résultats

### Niveaux de criticité

| Niveau | Délai | Action |
|--------|-------|--------|
| 🔴 **CRITICAL** | < 24h | Correction immédiate + rotation credentials |
| 🟠 **HIGH** | < 1 semaine | Correction prioritaire |
| 🟡 **MEDIUM** | < 1 mois | Planifier correction |
| 🟢 **LOW** | Backlog | À traiter si temps |

### Ordre de priorité

1. **🔑 Secrets détectés** → Rotation immédiate
2. **💉 Injections SQL/XSS** → Correction critique
3. **📦 CVE critiques** → Mise à jour dépendances
4. **🔐 SSL/TLS** → Améliorer configuration
5. **📋 En-têtes HTTP** → Ajouter headers manquants

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

## 🔄 Workflows par Rôle

### 💻 Développeur (Quotidien)

```bash
# Avant chaque commit
docker compose run --rm gitleaks              # Vérifier secrets
cd elearning && ./app.sh code-quality-check   # PHPStan + PHP-CS-Fixer
cd elearning && ./test-coverage.sh            # Tests unitaires
```

### 👨‍💼 Tech Lead (Hebdomadaire)

```bash
./security-scan.sh quick
./view-results.sh
# Traiter les problèmes critiques
```

### 🔒 Security Team (Release)

```bash
./security-scan.sh full
./view-results.sh
cat reports/security-report-*.md
# Valider avant mise en production
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

### Si CVE critiques

```bash
# 1. Voir détails
open reports/dependency-check/dependency-check-report.html

# 2. Mettre à jour
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

## 📈 Métriques Recommandées

- **Secrets exposés** : 0 (objectif strict)
- **CVE critiques** : 0
- **CVE hautes** : < 5
- **Score SSL** : A+ (TestSSL)
- **Score headers** : A (SecurityHeaders)
- **Temps de correction CRITICAL** : < 24h

---

## 📚 Ressources

- 🌐 [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- 🔍 [Semgrep Rules](https://semgrep.dev/explore)
- 🛡️ [OWASP ZAP Docs](https://www.zaproxy.org/docs/)
- 📦 [Snyk](https://snyk.io)
- 🐳 [Trivy Docs](https://aquasecurity.github.io/trivy/)

---

## 📁 Structure des Rapports

```
reports/
├── semgrep/              # Analyse code source
├── dependency-check/     # Vulnérabilités dépendances
├── gitleaks/             # Secrets détectés ⚠️
├── trivy/                # Vulnérabilités conteneurs
├── zap/                  # Scan web dynamique
├── nuclei/               # CVE et exposures
├── testssl/              # Configuration SSL/TLS
└── newman/               # Tests API
```

---

## 🎯 Checklist Avant Production

- [ ] `./security-scan.sh full` exécuté
- [ ] Aucun secret détecté (GitLeaks)
- [ ] Aucune CVE critique (Dependency Check)
- [ ] Score SSL ≥ A (TestSSL)
- [ ] En-têtes sécurité présents (SecurityHeaders)
- [ ] Tests API passent (Newman)
- [ ] Scan ZAP sans alerte HIGH
- [ ] Documentation des suppressions à jour

---

## 📚 Ressources

- 🌐 [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- 🔍 [Semgrep Rules](https://semgrep.dev/explore)
- 🛡️ [OWASP ZAP Docs](https://www.zaproxy.org/docs/)
- 📦 [Snyk](https://snyk.io)
- 🐳 [Trivy Docs](https://aquasecurity.github.io/trivy/)
- 🔐 [OSS Index](https://ossindex.sonatype.org/)

---

**Version** : 2.0.0  
**Dernière mise à jour** : 31 octobre 2025  
**Guide unifié** : Configuration + Réutilisation + DAST OVH

---

**Commencer maintenant :**
```bash
# 1. Configurer
cp .env.example .env && nano .env

# 2. Scanner
./security-scan.sh quick

# 3. Résultats
./view-results.sh
```
